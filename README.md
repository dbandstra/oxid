# Oxid
Oxid is an arcade-style game where you fight waves of monsters in a fixed-screen maze. This is more or less a clone of [Verminian Trap](http://locomalito.com/verminian_trap.php) (2013, Locomalito). Verminian Trap was originally inspired by [Wizard of Wor](https://en.wikipedia.org/wiki/Wizard_of_Wor) (1980, Midway).

Oxid is written in the [Zig](https://ziglang.org) programming language. I try to keep up with the master branch of Zig. Known to build with Zig commit `24fbd1f1d`.

## Installation
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

Game controls (these can be rebound in the menu):
* arrow keys: move
* space: shoot
* esc: leave game

Debug/cheat controls:
* backquote: fast forward
* backspace: skip to next wave
* F2: toggle rendering of move boxes
* F3: toggle invulnerability
* F4: toggle profiling spam
* F5: cycle through preserved graphics glitches

## Screenshot
![Screenshot](screenshot.png)

## Gameplay
The game goes on forever until you die. The waves are randomly generated (this was implemented in April 2019). There are three items which appear from time to time: power up, speed up, and 1-up.

* Things start to become unmanagably chaotic around level 30-35.
* Deaths often come in rapid succession. You may think you're doing well, only to lose it all in 30 seconds.
* My high score is about 12500, which took a bit less than 15 minutes.

## Code
Oxid uses a minimalistic Entity Component System, which is certainly overkill for a game like this, but for me it was a experiment in itself.

Here are the main gameplay-related files:
* [src/oxid/components.zig](src/components.zig) - struct definitions of each component type
* [src/oxid/frame.zig](src/frame.zig) - calls into systems
* [src/oxid/game.zig](src/game.zig) - component type registration
* [src/oxid/prototypes.zig](src/prototypes.zig) - entity spawning functions
* [src/oxid/systems/*.zig](src/systems/) - all of the systems (i.e. think functions)

The ECS framework itself is located in `gbe/`. It is small but quite rough and somewhat opaque as it involves a fair bit of metaprogramming.

Actually using the ECS requires very little boilerplate.
* To add a component type, add a struct to `components.zig` and register it in `game.zig`.
* To add an entity prototype, add a function to `prototypes.zig`.
* To add a system, add a file to `systems/` and import/call it in `frame.zig`.

Adding new graphics, sound effects, or input bindings is not as polished but still relatively easy. Documentation to come later.

## Notes
Low-level graphics code was originally based on andrewrk's [Tetris](https://github.com/andrewrk/tetris) demo for Zig.

Some sound effects from https://opengameart.org/content/512-sound-effects-8-bit-style

Uses [Dawnbringer's 16-colour palette](http://pixeljoint.com/forum/forum_posts.asp?TID=12795).

Uses my [zig-hunk](https://github.com/dbandstra/zig-hunk) and [zig-pcx](https://github.com/dbandstra/zig-pcx) one-file libraries, as well as [zang](https://github.com/dbandstra/zang).
