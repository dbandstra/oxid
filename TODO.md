GAMEPLAY:
- change squids to be spiders?
- red guys shouldn't shoot for the first few maps. and add the "fire knights" wave message when they do start shooting
- still get "who is this joker" in rare occasions - i think if you complete a wave and then step into a spawning monster? maybe if you are also invulnerable (blinking) after a spawn?
- more clever ai. for example, monsters that take side passages if you are looking down the corridor they are in
- monsters should sometimes randomly stop/change direction
- multiple explosions when squid is killed
- sound effects for web?
- sound effect when monsters speed up
- (maybe) come up with a function to create waves based on a difficulty rating as well as remembering old waves so it can "change things up" in terms of monster types

i have implement monsters getting out of the player's line of fire. but it tends to make the game easier. all you have to do is look at them and they'll basically run away. need to think about it some more.

CODE:
- sound: figure out how to start sounds at an offset into the mixing buffer. this becomes more important the larger the mix buffer is
- getting "who is this joker" if a bullet spawns inside another creature (because the bullet spawns in front of you)
- figure out how to refactor the component lists in game.zig so i only have to list them once
- use a single hunk memory system, and print allocation amounts for debugging
- optimization: player's "slipping around corners" code should operate on screen pixels, not subpixels
- get tests passing again
- add tests for physics
- collision: replace "speed_product" with something else (it will overflow if too many objects are colliding together)
- as for the "events".. maybe think functions should handle events from the previous frame? instead of having separate "think" and "react" routines. the purge function will then have to be removed/changed though.
- (may not be a priority for this game) need a solution for spawning a non-illusory phys object in a spot overlapping other objects. for now i've just players and bullets illusory
- 'transient' entities: entities that will be autoremoved at the end of the frame. they would include entities. i could also move some stuff like the 'line_of_fire' things to separate entities, this would make that simple. i'm just not sure if i want to lock into "end of frame" behaviours, i might want things to run less than once a frame... instead there should be some kind of system of messages and subscribers

paging system:
- do the old state/new state page flipping thing for deterministic game code (think functions can only read old state of other entities)
- after running a system (which can only write to one component type), flip the page for that component type? is that efficient...? it makes sense for Transform, but what else?

- there should be a way for an object to query all of the illusory physobjects it is intersecting. or actually, all physobjects period. sometimes illusory objects are supposed to provide a continuous effect (e.g. the webs that slow you down), which the event-collide system is not suited for.
  - however this is not a subpixel perfect solution for webs slowing the player down. you might cross the boundary of a web halfway through a move. the only perfect solution would be to build speed damping into the physics system itself. so maybe my above idea is actually bad.

GLITCHES:
- WholeTilesets looked better when the tileset image had less stuff in it (more blank transparent areas)...
- for QuadStrips glitch, would be crazier if GL_CULL_FACE were disabled, but then i should probably disable the glitch when rendering the level

GAMEPLAY IDEAS:
- enemy with a shield that deflects your bullets back at you
- exploding enemy
- enemy that multiplies (like mantra)
- flying enemy that can move over pits
- enemy that usually wanders, but occasionally chases, and increases speed when chasing (rushes at player)
- pits (implemented but not used in the map. one problem is that because the player is the same size as the corridors, he doesn't have space to face a pit that is to his side)
