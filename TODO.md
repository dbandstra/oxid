GAMEPLAY:
- you can't face a pit if there is no space
- player should only be able to have two bullets at a time
- monster bullets should not damage other monsters
- pausing

CODE:
- getting "who is this joker" if a bullet spawns inside another creature (because the bullet spawns in front of you)
- clean up game_draw.zig, there's a lot of duplicated code
- per-component type limits
- figure out how to refactor the component lists in game.zig so i only have to list them once
- choose_slot shouldn't crash! it should return errors
- use a single hunk memory system, and print allocation amounts for debugging
- refactor so main.zig is just SDL stuff. opengl stuff (that could be reused if we swap SDL for something else) is somewhere else
- do the old state/new state page flipping thing for deterministic game code (think functions can only read old state of other entities)
- optimization: player's "slipping around corners" code should operate on screen pixels, not subpixels
- get tests passing again
- collision: replace "speed_product" with something else (it will overflow if too many objects are colliding together)
- do something to avoid spawning monsters inside other monsters (or just make it possible to move out of something you're stuck in)
- pretty sure i've seen monsters touch bullets and turn around. bullets should either be illusory (like quake "solid_trigger"), or have two-way damage behaviour like the monsters do with players

IDEAS:
- enemy with a shield that deflects your bullets back at you
- exploding enemy
- enemy that multiples (like mantra)
- flying enemy that can move over pits
