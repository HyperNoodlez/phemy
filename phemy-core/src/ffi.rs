use std::ffi::{CStr, CString};
use std::os::raw::c_char;

/// Convert a C string pointer to a Rust &str.
/// Returns None if the pointer is null or the string is invalid UTF-8.
pub unsafe fn c_str_to_str<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        return None;
    }
    match CStr::from_ptr(ptr).to_str() {
        Ok(s) => Some(s),
        Err(e) => {
            log::warn!("FFI received invalid UTF-8 string: {}", e);
            None
        }
    }
}

/// Convert a Rust string to a heap-allocated C string.
/// The caller must free this with phemy_free_string().
pub fn str_to_c_char(s: &str) -> *mut c_char {
    match CString::new(s) {
        Ok(cs) => cs.into_raw(),
        Err(_) => std::ptr::null_mut(),
    }
}

/// Serialize a value to JSON and return as a C string.
/// The caller must free this with phemy_free_string().
pub fn to_json_c_char<T: serde::Serialize>(value: &T) -> *mut c_char {
    match serde_json::to_string(value) {
        Ok(json) => str_to_c_char(&json),
        Err(_) => std::ptr::null_mut(),
    }
}
