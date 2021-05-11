# Version history

## 1.0.2 (2021-05-11)

* Gameplay: Fix bug where player can get briefly stuck in a spawning monster when the player's invulnerability frames run out - player is now immediately killed in this situation.
* OpenGL frontend: add an 8px black margin around the scaled game view.
* Web frontend: don't preventDefault on key events that the game doesn't use.
* Fast forward now works in Web and SDL Renderer frontends (albeit without the blur effect).

## 1.0.1 (2021-01-05)

* Graphics: The middle block of the map is now a spaceship, not wall.
* Graphics: Adhere strictly to the 16 color palette (font is no longer pure white).
* Gameplay: Removed god mode cheat.
* Gameplay: Fix bug where a 1-up item was sometimes spawning after starting a new game.
* Web frontend: save config (volume, keybindings) to local storage.
* Web frontend: debug boxes (toggled with F2) are now supported.
* New experimental SDL Renderer frontend (`zig build sdl_renderer`).

## 1.0.0 (2020-12-20)

Initial tagged release.
