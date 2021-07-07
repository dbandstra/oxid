#!/bin/sh
set -e

OUTDIR="$1"

if [ -z "$OUTDIR" ]; then
    echo >&2 "missing argument (output directory)"
    exit 1
fi

if [ -e "$OUTDIR" ]; then
    echo >&2 "\"$OUTDIR\" already exists. delete it first"
    exit 1
fi

zig build -Drelease-small=true wasm

mkdir -p "$OUTDIR/assets"
cp -r assets/*.wav "$OUTDIR/assets/"
cp -r web/* "$OUTDIR/"
cp lib/zig-webgl/generated/webgl_bindings.js "$OUTDIR/js/webgl.js"
cp zig-out/lib/oxid_web.wasm "$OUTDIR/oxid.wasm"
