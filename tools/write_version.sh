#!/bin/sh

# TODO replace with native zig code, to be more windows-friendly

(git describe --tags 2>/dev/null || echo no-version) > zig-cache/version.txt
