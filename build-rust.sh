#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUST_DIR="$SCRIPT_DIR/kord-core"
DEPS_DIR="$RUST_DIR/target/release/deps"

echo "==> Building kord-core Rust library..."

export PATH="$HOME/.cargo/bin:$PATH"
export CXXFLAGS="-I/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/c++/v1"

cd "$RUST_DIR"

# ===========================================================================
# Pass 1: Normal build — produces all rlibs including whisper-rs-sys
# ===========================================================================
cargo build --release

# ===========================================================================
# Fix ggml symbol conflict between whisper-rs-sys and llama-cpp-sys-2.
#
# Both crates bundle their own ggml (ABI-incompatible versions) and embed
# native .o files into their rlibs. When linked into the cdylib, the linker
# resolves duplicate ggml symbols to ONE copy, causing the other crate to
# crash (wrong ABI).
#
# Fix: Use `ld -r -unexported_symbols_list` to pre-link whisper's native
# objects into a single merged .o with ggml/gguf symbols made private.
# Whisper uses its own (local) ggml; llama uses its own (global) ggml.
# ===========================================================================
localize_ggml_in_whisper_rlib() {
    local rlib="$1"
    local work_dir="$2"

    echo "  Checking $(basename "$rlib")..."

    # List rlib members
    local members
    members=$(ar t "$rlib")

    # Check if already merged (idempotent)
    if echo "$members" | grep -q "^whisper_merged\.o$"; then
        echo "  Already merged, skipping."
        return 1  # Signal no modification
    fi

    # Find native C/C++ objects (not Rust codegen units which have .rcgu.o)
    local native_objects=()
    while IFS= read -r member; do
        case "$member" in
            *.c.o) native_objects+=("$member") ;;
            *.cpp.o)
                if [[ "$member" != *rcgu* ]]; then
                    native_objects+=("$member")
                fi
                ;;
        esac
    done <<< "$members"

    if [ ${#native_objects[@]} -eq 0 ]; then
        echo "  No native objects found, skipping."
        return 1
    fi

    echo "  Found ${#native_objects[@]} native objects: ${native_objects[*]}"

    local merge_dir="$work_dir/whisper_merge"
    mkdir -p "$merge_dir"

    # Extract native .o files
    (cd "$merge_dir" && ar x "$rlib" "${native_objects[@]}")

    # Build paths for extracted objects
    local obj_paths=()
    for obj in "${native_objects[@]}"; do
        obj_paths+=("$merge_dir/$obj")
    done

    # Write unexported symbols list (ggml/gguf become private)
    local unexport_file="$merge_dir/ggml_unexport.txt"
    printf '_ggml_*\n_gguf_*\n' > "$unexport_file"

    # Pre-link into single relocatable object with ggml symbols made private
    local merged="$merge_dir/whisper_merged.o"
    echo "  Running ld -r -unexported_symbols_list..."
    /usr/bin/ld -r \
        -unexported_symbols_list "$unexport_file" \
        -o "$merged" \
        "${obj_paths[@]}"

    # Verify ggml symbols are now local
    local global_ggml
    global_ggml=$(nm -gU "$merged" 2>/dev/null | grep -c "^.* [TSD] _ggml_" || true)
    echo "  Global ggml symbols remaining: $global_ggml (should be 0 or near 0)"

    # Remove original native .o files from rlib
    for obj in "${native_objects[@]}"; do
        ar d "$rlib" "$obj"
    done

    # Add merged object
    ar r "$rlib" "$merged"
    ranlib "$rlib"

    echo "  Done! Merged ${#native_objects[@]} objects into whisper_merged.o"
    return 0  # Signal modification was made
}

RLIB_MODIFIED=false
for rlib in "$DEPS_DIR"/libwhisper_rs_sys-*.rlib; do
    [ -f "$rlib" ] || continue
    work_dir=$(mktemp -d)
    if localize_ggml_in_whisper_rlib "$rlib" "$work_dir"; then
        RLIB_MODIFIED=true
    fi
    rm -rf "$work_dir"
done

# ===========================================================================
# Pass 2: Re-link the cdylib with the modified rlib
# ===========================================================================
if [ "$RLIB_MODIFIED" = true ]; then
    echo "==> Re-linking cdylib with localized ggml symbols..."
    # Touch lib.rs to force cargo to re-link the cdylib
    touch "$RUST_DIR/src/lib.rs"
    cargo build --release
fi

# Generate C header with cbindgen
if command -v cbindgen &> /dev/null; then
    echo "==> Generating C header with cbindgen..."
    cbindgen --config cbindgen.toml --crate kord-core --output include/kord_core.h
else
    echo "WARNING: cbindgen not installed. Run: cargo install cbindgen"
    echo "Using existing header if available."
fi

# Copy the dylib to project root
DYLIB_PATH="$RUST_DIR/target/release/libkord_core.dylib"
if [ -f "$DYLIB_PATH" ]; then
    cp "$DYLIB_PATH" "$SCRIPT_DIR/libkord_core.dylib"

    # Set the install name to absolute path for development.
    install_name_tool -id "$SCRIPT_DIR/libkord_core.dylib" "$SCRIPT_DIR/libkord_core.dylib" 2>/dev/null \
        && codesign -f -s - "$SCRIPT_DIR/libkord_core.dylib" 2>/dev/null \
        || echo "  (install_name_tool skipped — using build path as install name)"

    echo "==> Copied libkord_core.dylib to project root"
else
    echo "ERROR: libkord_core.dylib not found at $DYLIB_PATH"
    exit 1
fi

echo "==> Done! Library: $SCRIPT_DIR/libkord_core.dylib"
echo "==> Header:  $RUST_DIR/include/kord_core.h"
