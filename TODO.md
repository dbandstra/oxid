GAMEPLAY:
- player movement: if there is a corner passage nearby in front of you, and you are pushing into the wall on that side, continue to walk forward, so you "slip" around the corner. the hungarian guy's js remake of wizard of wor had this behaviour
- enemies should collide with each other
- you can't face a pit if there is no space
- collision detection vs enemies should be more forgiving
- player should only be able to have two bullets at a time
- some enemies should shoot

CODE:
- figure out how to refactor the component lists in game.zig so i only have to list them once
- refactor thinks so entities set their velocity, and the phys frame moves them
- choose_slot shouldn't crash! it should return errors
- use a single hunk memory system, and print allocation amounts for debugging
- refactor so main.zig is just SDL stuff. opengl stuff (that could be reused if we swap SDL for something else) is somewhere else

IDEAS:
- enemy with a shield that deflects your bullets back at you
- exploding enemy
- enemy that multiples (like mantra)
