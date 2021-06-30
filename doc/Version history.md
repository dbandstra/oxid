# Version history

Starting with version 1.1.0, I will be incrementing the patch version (third
digit) only if gameplay has not been changed at all (demo files remain
compatible). If the gameplay changes, the minor version (second digit) will
be incremented. The major version (first digit) will probably never change.

## 1.1.0 (not tagged yet)

Demo recording: The game now records every game you play. It keeps the 10
most recent recordings. You can play them back through the new "Recorded
games" menu.

New mechanic: Oxygen level. This creates a "time limit" which ensures that
games always come to an end, and prevents players from running around with
one monster left, clearing webs or waiting for powerups to spawn. It also
may change strategy a little bit. Details:

* Oxygen depletes over time.
* Collecting a "coin" pellet restores a little bit of oxygen.
* When you run out of oxygen, you die.
* Oxygen is reset to full when you die and when you complete a wave.

Other changes:

* Gameplay: Fix bug where monster remains invulnerable after "telefragging"
  the player (behavior added in 1.0.2).
* The "drop web" sound was replaced, with the goal of being less grating.
* The status bar visuals have been rearranged a bit.
* Added "super fast forward" (hold shift-backquote). This speeds the game up
  by 16x (regular fast forward is 4x).

## 1.0.2 (2021-05-11)

* Gameplay: Fix bug where player can get briefly stuck in a spawning monster
  when the player's invulnerability frames run out - player is now
  immediately killed in this situation.
* OpenGL frontend: add an 8px black margin around the scaled game view.
* Web frontend: don't preventDefault on key events that the game doesn't use.
* Fast forward now works in Web and SDL Renderer frontends (albeit without
  the blur effect).

## 1.0.1 (2021-01-05)

* Graphics: The middle block of the map is now a spaceship, not wall.
* Graphics: Adhere strictly to the 16 color palette (font is no longer pure
  white).
* Gameplay: Removed god mode cheat.
* Gameplay: Fix bug where a 1-up item was sometimes spawning after starting a
  new game.
* Web frontend: save config (volume, keybindings) to local storage.
* Web frontend: debug boxes (toggled with F2) are now supported.
* New experimental SDL Renderer frontend (`zig build sdl_renderer`).

## 1.0.0 (2020-12-20)

Initial tagged release.
