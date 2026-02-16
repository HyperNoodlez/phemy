#!/usr/bin/env python3
"""Remove duplicate ggml objects from a static library.

whisper-rs-sys and llama-cpp-sys-2 both bundle ggml, causing duplicate symbols.
This script removes the whisper copies (first occurrence) of the duplicated
ggml object files, keeping the llama-cpp copies (later occurrence).
"""
import os
import sys
import subprocess
import tempfile


def parse_ar(path):
    """Parse a BSD ar archive, yielding (member_name, object_data) tuples."""
    with open(path, "rb") as f:
        magic = f.read(8)
        assert magic == b"!<arch>\n", f"Not an ar archive: {magic}"

        while True:
            # Align to 2-byte boundary
            pos = f.tell()
            if pos % 2 == 1:
                f.read(1)

            header = f.read(60)
            if len(header) < 60:
                break

            name_field = header[0:16].decode("ascii").strip()
            size = int(header[48:58].decode("ascii").strip())
            data = f.read(size)

            # Handle BSD extended names: #1/XX means name is XX bytes at start of data
            if name_field.startswith("#1/"):
                name_len = int(name_field[3:])
                member_name = data[:name_len].rstrip(b"\x00").decode("ascii", errors="replace")
                object_data = data[name_len:]
            else:
                member_name = name_field.rstrip("/")
                object_data = data

            # Skip symbol table and string table entries
            if member_name.startswith("__.SYMDEF") or member_name in ("/", "//", ""):
                continue

            yield member_name, object_data


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.a> <output.a>")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]

    # Parse all members
    members = list(parse_ar(input_path))
    names = [name for name, _ in members]

    # These ggml object files are bundled by both whisper-rs-sys and llama-cpp-sys-2
    duplicate_candidates = {"ggml.c.o", "ggml-alloc.c.o", "ggml-backend.c.o", "ggml-quants.c.o"}

    # Find which names actually appear more than once
    from collections import Counter
    counts = Counter(names)
    actual_dups = {n for n in duplicate_candidates if counts[n] > 1}

    if not actual_dups:
        print("No duplicate ggml objects found, copying as-is")
        subprocess.run(["cp", input_path, output_path])
        return

    # For each duplicate, mark the FIRST occurrence for removal (whisper's copy)
    seen = {}
    skip_indices = set()
    for i, name in enumerate(names):
        if name in actual_dups:
            if name not in seen:
                seen[name] = i  # first occurrence = whisper
            else:
                skip_indices.add(seen[name])  # mark first for removal

    print(f"Removing {len(skip_indices)} whisper ggml objects:")
    for idx in sorted(skip_indices):
        print(f"  [{idx}] {names[idx]}")

    # Extract non-skipped members to temp files
    with tempfile.TemporaryDirectory() as tmpdir:
        extracted = []
        for i, (name, data) in enumerate(members):
            if i in skip_indices:
                continue

            out_name = f"{i:05d}_{name}"
            out_path = os.path.join(tmpdir, out_name)
            with open(out_path, "wb") as out:
                out.write(data)
            extracted.append(out_path)

        print(f"Repacking {len(extracted)} objects into {output_path}")

        if os.path.exists(output_path):
            os.remove(output_path)

        subprocess.run(["ar", "rcs", output_path] + extracted, check=True)

    print("Done!")


if __name__ == "__main__":
    main()
