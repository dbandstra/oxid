# Todo

## Bugs
- input gets lagged sometimes
  - i've gotten it with fast forwarding. sometimes (not always), while fast forwarding, input is a bit delayed, and after releasing the fast forward key, the game keeps fast forwarding for another half second
  - unique_id reported getting it after moving the window

## Gameplay
- change squids to be spiders?
- still get "who is this joker" in rare occasions - i think if you complete a wave and then step into a spawning monster? maybe if you are also invulnerable (blinking) after a spawn?
- more clever ai. for example, monsters that take side passages if you are looking down the corridor they are in
- monsters should sometimes randomly stop/change direction
- multiple explosions when squid is killed
- sound effect when monsters speed up
- when you respawn after dying, you shouldn't have to release and repress movement keys

i have implemented monsters getting out of the player's line of fire. but it tends to make the game easier. all you have to do is look at them and they'll basically run away. need to think about it some more.

## Code
- document the major pieces of code (e.g. GBE stuff), at least with comments, maybe also with some dedicated markdown files
- shouldn't removals take effect after every system? right now, if you remove an entity, it just adds a 'removal' entry. doesn't even set is_active to false. so iterators will still hit those entities until the end of the entire frame.
- not being able to init the sound device should not be a fatal error
- getting "who is this joker" if a bullet spawns inside another creature (because the bullet spawns in front of you)
- optimization: player's "slipping around corners" code should operate on screen pixels, not subpixels
- add tests for physics
- collision: replace "speed_product" with something else (it will overflow if too many objects are colliding together)
- (may not be a priority for this game) need a solution for spawning a non-illusory phys object in a spot overlapping other objects. for now i've just players and bullets illusory

### Component system
- SystemData should be able to include more than just 'self' stuff. it should probably just include all component types that you want access to. a separate layer would build the 'self' iteration.
  - useful e.g. for monsters to get the GameController 'singleton'
  - this would entail getting rid of the `find` functions that operate on a GameSession
- some kind of hierarchy? like a component can (effectively) contain an entire Gbe instance. i think this would require allocating Gbes on the heap though.
  - it would be used for MainController containing GameController, and GameController containing all the other stuff. that may reduce the number of systems needed (e.g. currently, MainController thinks, then GameController thinks, then MainController reacts to GameController's events - three systems).
  - currently the MainController ends the game by destroying all components except MainController. this is kinda hacky, an ownership system would be better. but all things considered it might be overengineering

### Events
- maybe think functions should handle events from the previous frame? instead of having separate "think" and "react" routines. the purge function will then have to be removed/changed though.
  - no, this is not flexible. you should be free to handle events whenever you want. maybe same frame, maybe next frame.
- 'transient' entities: entities that will be autoremoved at the end of the frame. they would include events. i could also move some stuff like the 'line_of_fire' things to separate entities, this would make that simple. i'm just not sure if i want to lock into "end of frame" behaviours, i might want things to run less than once a frame... instead there should be some kind of system of messages and subscribers

events always have a recipient. they go straight to the recipient's inbox for that event type. there is no list of active events anywhere. the recipients decide when to purge the inbox.
- recipient components must have a setup up inbox for each event type. an inbox is actually a FUNCTION. thus, recipient can decide how to accumulate/aggregate incoming messages.
- presumably, this function will mutate the recipient component's state. but this breaks all the rules!
- so, it should operate on something separate from the component itself. probably a struct specific to that event type, for the recipient (so, 1:1 along with the function).
- i don't know if this makes any sense at all in terms of cache coherence, when spawning the events.
- so far, everything i've come up with sounds like overengineering.

### Paging system?
- do the old state/new state page flipping thing for deterministic game code (think functions can only read old state of other entities)
- after running a system (which can only write to one component type), flip the page for that component type? is that efficient...? it makes sense for Transform, but what else?

- there should be a way for an object to query all of the illusory physobjects it is intersecting. or actually, all physobjects period. sometimes illusory objects are supposed to provide a continuous effect (e.g. the webs that slow you down), which the event-collide system is not suited for.
  - however this is not a subpixel perfect solution for webs slowing the player down. you might cross the boundary of a web halfway through a move. the only perfect solution would be to build speed damping into the physics system itself. so maybe my above idea is actually bad.

## Glitches
- WholeTilesets looked better when the tileset image had less stuff in it (more blank transparent areas)...
- for QuadStrips glitch, would be crazier if GL_CULL_FACE were disabled, but then i should probably disable the glitch when rendering the level

## Gameplay ideas
Beyond cloning Verminian Trap.

- (maybe) come up with a function to create waves based on a difficulty rating as well as remembering old waves so it can "change things up" in terms of monster types
- (maybe) random maze generation
- enemy with a shield that deflects your bullets back at you
- exploding enemy
- enemy that multiplies (like mantra)
- flying enemy that can move over pits
- enemy that usually wanders, but occasionally chases, and increases speed when chasing (rushes at player)
- pits (implemented but not used in the map. one problem is that because the player is the same size as the corridors, he doesn't have space to face a pit that is to his side)
