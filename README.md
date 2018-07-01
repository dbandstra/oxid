# Oxid
Oxid is an arcade-style game where you fight waves of monsters in a fixed-screen maze. The name is just some random letters I typed on my keyboard. Not to be confused with [Oxyd](https://en.wikipedia.org/wiki/Oxyd).

This more or less a clone of [Verminian Trap](http://locomalito.com/verminian_trap.php) (2013, Locomalito), one of my favourite games on the ill-fated Ouya. Verminian Trap was originally inspired by [Wizard of Wor](https://en.wikipedia.org/wiki/Wizard_of_Wor) (1980, Midway). Oxid is currently not nearly as fun as Verminian Trap, see TODO.md for planned features.

The project is very early in development, but it's playable. No screenshots yet.

# Why?
My primary motivation is to experiment with, battle-test, and possibly contribute to the [Zig](https://ziglang.org) programming language.

I've also been interested in game programming for a long time. I chose to clone an existing, simple game in order to prevent the scope creep that killed all of my previous game projects over the years. If I "complete" this project, I might work on a spinoff with more original features.

# How to play
* Install [SDL2](https://www.libsdl.org/) and [libepoxy](https://github.com/anholt/libepoxy)
* Install [Zig](https://ziglang.org/download/) (get it from master, version 0.2.0 is too old)
* `zig build play`

# Notes
Low-level graphics code was lifted from andrewrk's [Tetris](https://github.com/andrewrk/tetris) demo for Zig.

Uses my [Zigutils](https://github.com/dbandstra/zigutils) library of random stuff.
