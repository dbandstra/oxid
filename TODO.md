GAMEPLAY:
- enemies should start at faster speeds on later levels
- you can't face a pit if there is no space
- remove the pits
- fast bug monsters
- it looks too much like a glitch when the enemies freeze after you die
- what should happen if the player dies and respawns while an enemy is his spawn location? should the player be able to ghost through enemies during his blinking invulnerability phase?

CODE:
- getting "who is this joker" if a bullet spawns inside another creature (because the bullet spawns in front of you)
- figure out how to refactor the component lists in game.zig so i only have to list them once
- use a single hunk memory system, and print allocation amounts for debugging
- refactor so main.zig is just SDL stuff. opengl stuff (that could be reused if we swap SDL for something else) is somewhere else
- do the old state/new state page flipping thing for deterministic game code (think functions can only read old state of other entities)
- optimization: player's "slipping around corners" code should operate on screen pixels, not subpixels
- get tests passing again
- add tests for physics
- collision: replace "speed_product" with something else (it will overflow if too many objects are colliding together)
- move all drawing stuff into a file, all opengl stuff, with layer of abstraction so that a software renderer could be done (i probably won't bother to do one though)
- as for the "events".. maybe think functions should handle events from the previous frame? instead of having separate "think" and "react" routines. the purge function will then have to be removed/changed though.

paging system:
- after running a system (which can only write to one component type), flip the page for that component type? is that efficient...? it makes sense for Transform, but what else?

IDEAS:
- enemy with a shield that deflects your bullets back at you
- exploding enemy
- enemy that multiplies (like mantra)
- flying enemy that can move over pits
- enemy that usually wanders, but occasionally chases, and increases speed when chasing (rushes at player)
