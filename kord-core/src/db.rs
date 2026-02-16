use anyhow::Result;
use rusqlite::Connection;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Mutex;
use uuid::Uuid;

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

pub struct Database {
    pub conn: Mutex<Connection>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryEntry {
    pub id: String,
    pub raw_transcript: String,
    pub optimized_prompt: Option<String>,
    pub prompt_mode: String,
    pub llm_provider: Option<String>,
    pub duration_secs: f64,
    pub created_at: String,
}

/// Global database instance
static DB: std::sync::LazyLock<Mutex<Option<Database>>> =
    std::sync::LazyLock::new(|| Mutex::new(None));

/// Initialize the database at the given path
pub fn init(db_path: &PathBuf) -> Result<()> {
    if let Some(parent) = db_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let conn = Connection::open(db_path)?;

    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS history (
            id TEXT PRIMARY KEY,
            raw_transcript TEXT NOT NULL,
            optimized_prompt TEXT,
            prompt_mode TEXT NOT NULL DEFAULT 'clean',
            llm_provider TEXT,
            duration_secs REAL NOT NULL DEFAULT 0.0,
            created_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS vocabulary (
            id TEXT PRIMARY KEY,
            word TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_history_created_at ON history(created_at DESC);",
    )?;

    let mut db = DB.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
    *db = Some(Database {
        conn: Mutex::new(conn),
    });

    // Set restrictive permissions (owner-only read/write) on the database file
    #[cfg(unix)]
    {
        let perms = std::fs::Permissions::from_mode(0o600);
        if let Err(e) = std::fs::set_permissions(db_path, perms) {
            log::warn!("Failed to set database file permissions: {}", e);
        }
    }

    log::info!("Database initialized at {:?}", db_path);
    Ok(())
}

/// Get a reference to the global database
fn with_db<T, F: FnOnce(&Database) -> Result<T>>(f: F) -> Result<T> {
    let guard = DB.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
    let db = guard
        .as_ref()
        .ok_or_else(|| anyhow::anyhow!("Database not initialized"))?;
    f(db)
}

pub fn insert_history(entry: &HistoryEntry) -> Result<()> {
    with_db(|db| {
        let conn = db.conn.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        conn.execute(
            "INSERT INTO history (id, raw_transcript, optimized_prompt, prompt_mode, llm_provider, duration_secs, created_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![
                entry.id,
                entry.raw_transcript,
                entry.optimized_prompt,
                entry.prompt_mode,
                entry.llm_provider,
                entry.duration_secs,
                entry.created_at,
            ],
        )?;
        Ok(())
    })
}

pub fn get_history(limit: usize, offset: usize) -> Result<Vec<HistoryEntry>> {
    with_db(|db| {
        let conn = db.conn.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        let mut stmt = conn.prepare(
            "SELECT id, raw_transcript, optimized_prompt, prompt_mode, llm_provider, duration_secs, created_at
             FROM history ORDER BY created_at DESC LIMIT ?1 OFFSET ?2",
        )?;

        let entries = stmt
            .query_map(rusqlite::params![limit, offset], |row| {
                Ok(HistoryEntry {
                    id: row.get(0)?,
                    raw_transcript: row.get(1)?,
                    optimized_prompt: row.get(2)?,
                    prompt_mode: row.get(3)?,
                    llm_provider: row.get(4)?,
                    duration_secs: row.get(5)?,
                    created_at: row.get(6)?,
                })
            })?
            .collect::<Result<Vec<_>, _>>()?;

        Ok(entries)
    })
}

pub fn delete_history_entry(id: &str) -> Result<()> {
    with_db(|db| {
        let conn = db.conn.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        conn.execute("DELETE FROM history WHERE id = ?1", [id])?;
        Ok(())
    })
}

pub fn clear_history() -> Result<()> {
    with_db(|db| {
        let conn = db.conn.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
        conn.execute("DELETE FROM history", [])?;
        Ok(())
    })
}

pub fn new_history_entry(
    raw_transcript: String,
    optimized_prompt: Option<String>,
    prompt_mode: String,
    llm_provider: Option<String>,
    duration_secs: f64,
) -> HistoryEntry {
    HistoryEntry {
        id: Uuid::new_v4().to_string(),
        raw_transcript,
        optimized_prompt,
        prompt_mode,
        llm_provider,
        duration_secs,
        created_at: chrono::Utc::now().to_rfc3339(),
    }
}
