# Oxid
Oxid is an arcade-style game where you fight waves of monsters in a fixed-screen maze. This is more or less a clone of [Verminian Trap](http://locomalito.com/verminian_trap.php) (2013, Locomalito). Verminian Trap was originally inspired by [Wizard of Wor](https://en.wikipedia.org/wiki/Wizard_of_Wor) (1980, Midway).

Oxid is written in the [Zig](https://ziglang.org) programming language (requires version 0.7.x).

[Play online here!](https://dbandstra.github.io/oxid/)

![Screenshot](screenshot.png)

## Building
Note: After cloning the oxid repository, make sure to update the submodules (`git submodule init` followed by `git submodule update`).

Oxid can be built into a native executable or a WebAssembly binary.

### Native build
The native build requires [SDL2](https://www.libsdl.org/) and should work on Linux, Mac and Windows (untested).

To build and run the debug build:
```sh
zig build play

# or, equivalently:
zig build
zig-cache/oxid
```

To build and run the release build:
```sh
zig build -Drelease-safe=true
zig-cache/oxid
```

Oxid supports a few command-line options for things like refresh rate and audio sample rate. Run `zig-cache/oxid --help` for a listing.

### WebAssembly build
The WebAssembly build has no third-party requirements.

To build and serve:
```sh
sh build_web.sh www  # choose any destination directory
cd www
python3 -m http.server  # or any other web server of your choice
```

## How to play
Game controls (these can be rebound in the menu):
* arrow keys: move
* space: shoot
* esc: open menu

Menu controls:
* arrow keys: move cursor
* enter: select
* esc: go back

Debug/cheat controls:
* backquote: fast forward (not available in web version)
* backspace: skip to next wave
* F2: toggle rendering of move boxes
* F4: toggle profiling spam (not available in web version or in ReleaseSmall)

## Code organization
See [doc/Code organization.md](doc/Code%20organization.md)

## Notes
Low-level graphics code was originally based on andrewrk's [Tetris](https://github.com/andrewrk/tetris) demo for Zig. WebAssembly code was based on raulgrell's [fork](https://github.com/raulgrell/tetris) of the same project.

Some sound effects from https://opengameart.org/content/512-sound-effects-8-bit-style

Uses [Dawnbringer's 16-color palette](http://pixeljoint.com/forum/forum_posts.asp?TID=12795).

Uses Hejsil's [zig-clap](https://github.com/Hejsil/zig-clap), my [zig-hunk](https://github.com/dbandstra/zig-hunk), [zig-pcx](https://github.com/dbandstra/zig-pcx) and [zig-wav](https://github.com/dbandstra/zig-wav) one-file libraries, as well as [zang](https://github.com/dbandstra/zang) for audio.
