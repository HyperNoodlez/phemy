#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/Phemy.app"

echo "=== Phemy .dmg Installer Builder ==="
echo "Project: $PROJECT_DIR"
echo ""

# =========================================================================
# Step A — Build Rust (release, with correct install name for .app bundle)
# =========================================================================
echo "==> Step A: Building Rust library..."

# First, run the normal build (with ggml dedup)
"$PROJECT_DIR/build-rust.sh"

# Now re-link ONLY the phemy-core cdylib with the correct install name.
# We use `cargo rustc` which passes flags only to the specified crate's
# final compilation — NOT to build scripts (which are executables and
# would reject -install_name).
echo "==> Step A.1: Re-linking cdylib with @executable_path install name..."
cd "$PROJECT_DIR/phemy-core"
touch src/lib.rs  # force cargo to re-link
cargo rustc --release --lib -- \
    -C link-arg=-install_name \
    -C link-arg=@executable_path/../Frameworks/libphemy_core.dylib

# Copy the re-linked dylib to project root (overwriting the one build-rust.sh placed)
RELINKED_DYLIB="$PROJECT_DIR/phemy-core/target/release/libphemy_core.dylib"
if [ -f "$RELINKED_DYLIB" ]; then
    cp "$RELINKED_DYLIB" "$PROJECT_DIR/libphemy_core.dylib"
    echo "  Copied re-linked dylib to project root"
else
    echo "ERROR: Re-linked dylib not found at $RELINKED_DYLIB"
    exit 1
fi

echo ""

# =========================================================================
# Step B — Build Swift (release)
# =========================================================================
echo "==> Step B: Building Swift (release)..."

cd "$PROJECT_DIR"
swift build -c release

echo ""

# =========================================================================
# Step C — Assemble .app bundle
# =========================================================================
echo "==> Step C: Assembling Phemy.app bundle..."

# Clean previous build
rm -rf "$APP_DIR"

# Create directory structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Frameworks"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy executable
EXECUTABLE="$PROJECT_DIR/.build/arm64-apple-macosx/release/PhemyNative"
if [ ! -f "$EXECUTABLE" ]; then
    echo "ERROR: Executable not found at $EXECUTABLE"
    exit 1
fi
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/PhemyNative"

# Copy dylib into Frameworks/
DYLIB="$PROJECT_DIR/libphemy_core.dylib"
if [ ! -f "$DYLIB" ]; then
    echo "ERROR: libphemy_core.dylib not found at $DYLIB"
    exit 1
fi
cp "$DYLIB" "$APP_DIR/Contents/Frameworks/libphemy_core.dylib"

# Copy SPM resource bundle (contains all UI assets the app loads via Bundle.module)
RESOURCE_BUNDLE="$PROJECT_DIR/.build/arm64-apple-macosx/release/PhemyNative_PhemyNative.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/PhemyNative_PhemyNative.bundle"
    echo "  Copied SPM resource bundle"
else
    echo "WARNING: SPM resource bundle not found at $RESOURCE_BUNDLE"
fi

# Copy AppIcon.icns to Resources/ root (macOS Finder reads it from here)
ICON="$PROJECT_DIR/Sources/PhemyNative/Resources/AppIcon.icns"
if [ -f "$ICON" ]; then
    cp "$ICON" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  Copied AppIcon.icns"
else
    echo "WARNING: AppIcon.icns not found at $ICON"
fi

# =========================================================================
# Verify no missing dependencies
# =========================================================================
echo ""
echo "==> Verifying dynamic library dependencies..."

check_deps() {
    local binary="$1"
    local label="$2"
    local bad_deps

    bad_deps=$(otool -L "$binary" | tail -n +2 | awk '{print $1}' | grep -v -E '^(@executable_path/|/System/Library/|/usr/lib/)' || true)

    if [ -n "$bad_deps" ]; then
        echo "ERROR: $label has non-system/non-bundled dependencies:"
        echo "$bad_deps"
        exit 1
    fi
    echo "  $label: OK (all deps are system or @executable_path)"
}

check_deps "$APP_DIR/Contents/MacOS/PhemyNative" "PhemyNative executable"
check_deps "$APP_DIR/Contents/Frameworks/libphemy_core.dylib" "libphemy_core.dylib"

echo ""

# =========================================================================
# Step D — Write Info.plist
# =========================================================================
echo "==> Step D: Writing Info.plist..."

cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PhemyNative</string>
    <key>CFBundleIdentifier</key>
    <string>com.labgarge.phemy</string>
    <key>CFBundleName</key>
    <string>Phemy</string>
    <key>CFBundleDisplayName</key>
    <string>Phemy</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Phemy needs microphone access to record your voice and transcribe it into text.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>Phemy needs accessibility access to capture keyboard shortcuts and paste text into other applications.</string>
</dict>
</plist>
PLIST

echo "  Info.plist written"
echo ""

# =========================================================================
# Step E — Ad-hoc codesign
# =========================================================================
echo "==> Step E: Ad-hoc codesigning..."

codesign --force --sign - --deep "$APP_DIR"

echo "  Codesigned Phemy.app"
echo ""

# =========================================================================
# Step F — Create .dmg
# =========================================================================
echo "==> Step F: Creating .dmg..."

DMG_PATH="$DIST_DIR/Phemy.dmg"
hdiutil create -volname "Phemy" -srcfolder "$APP_DIR" -ov -format UDZO "$DMG_PATH"

echo ""
echo "=== Done! ==="
echo "  App:  $APP_DIR"
echo "  DMG:  $DMG_PATH"
echo ""
echo "To install: open $DMG_PATH and drag Phemy.app to /Applications"
