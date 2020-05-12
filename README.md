# Oxid
Oxid is an arcade-style game where you fight waves of monsters in a fixed-screen maze. This is more or less a clone of [Verminian Trap](http://locomalito.com/verminian_trap.php) (2013, Locomalito). Verminian Trap was originally inspired by [Wizard of Wor](https://en.wikipedia.org/wiki/Wizard_of_Wor) (1980, Midway).

Oxid is written in the [Zig](https://ziglang.org) programming language (requires version 0.6.0).

[Play online here!](https://dbandstra.github.io/oxid/)

![Screenshot](screenshot.png)

## Installation
Oxid can be built into a native executable or a Web Assembly binary.

The native version has the following requirements:
* Install [SDL2](https://www.libsdl.org/) and [libepoxy](https://github.com/anholt/libepoxy)
* Install [Zig](https://ziglang.org/download/). Use master, or if that doesn't work, the abovementioned commit hash.
* After cloning the oxid repository, you may have to explicitly update the submodules: `git submodule init` followed by `git submodule update`

## How to play
To run the debug build:
```
zig build play
```

To build and run the release build:
```
zig build -Drelease-fast=true
zig-cache/oxid
```

The native version supports a few command-line options for things like audio sample rate. Run `zig-cache/oxid --help` for a listing.

To build the Web Assembly version (currently broken, see [#43](https://github.com/dbandstra/oxid/issues/43)):
```
zig build wasm
```
Then run a web server (such as Python's SimpleHTTPServer) from the oxid root folder.

Game controls (these can be rebound in the menu):
* arrow keys: move
* space: shoot
* esc: open menu

Debug/cheat controls:
* backquote: fast forward (not in web version)
* backspace: skip to next wave
* F2: toggle rendering of move boxes
* F3: toggle invulnerability
* F4: toggle profiling spam (not in web version)
* F5: cycle through preserved graphics glitches (not in web version)

## Notes
Low-level graphics code was originally based on andrewrk's [Tetris](https://github.com/andrewrk/tetris) demo for Zig. Web Assembly code was based on raulgrell's [fork](https://github.com/raulgrell/tetris) of the same project.

Some sound effects from https://opengameart.org/content/512-sound-effects-8-bit-style

Uses [Dawnbringer's 16-colour palette](http://pixeljoint.com/forum/forum_posts.asp?TID=12795).

Uses Hejsil's [zig-clap](https://github.com/Hejsil/zig-clap), my [zig-hunk](https://github.com/dbandstra/zig-hunk), [zig-pcx](https://github.com/dbandstra/zig-pcx) and [zig-wav](https://github.com/dbandstra/zig-wav) one-file libraries, as well as [zang](https://github.com/dbandstra/zang) for audio.
