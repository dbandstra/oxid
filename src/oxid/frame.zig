const std = @import("std");
const GameComponentLists = @import("game.zig").GameComponentLists;
const GameSession = @import("game.zig").GameSession;
const physicsFrame = @import("physics.zig").physicsFrame;
const C = @import("components.zig");
const Prototypes = @import("prototypes.zig");

pub fn gameInit(gs: *GameSession) void {
  _ = Prototypes.GameController.spawn(gs);
  _ = Prototypes.PlayerController.spawn(gs);
}

// run before "middleware" (rendering, sound, etc)
pub fn gameFrame(gs: *GameSession) void {
  @import("systems/game_controller_input.zig").run(gs);
  @import("systems/player_input.zig").run(gs);

  const num_frames = blk: {
    const gc = gs.findFirst(C.GameController).?;

    if (gc.paused) {
      break :blk u32(0);
    } else if (gc.fast_forward) {
      break :blk u32(4);
    } else {
      break :blk u32(1);
    }
  };

  var i: u32 = 0; while (i < num_frames) : (i += 1) {
    @import("systems/game_controller.zig").run(gs);
    @import("systems/player_controller.zig").run(gs);
    @import("systems/animation.zig").run(gs);
    @import("systems/player_movement.zig").run(gs);
    @import("systems/monster_movement.zig").run(gs);
    @import("systems/bullet.zig").run(gs);
    @import("systems/creature.zig").run(gs);
    @import("systems/pickup.zig").run(gs);

    physicsFrame(gs);

    // pickups react to event_collide, spawn event_confer_bonus
    @import("systems/pickup_collide.zig").run(gs);
    // bullets react to event_collide, spawn event_take_damage
    @import("systems/bullet_collide.zig").run(gs);
    // monsters react to event_collide, damage others
    @import("systems/monster_touch_response.zig").run(gs);
    // player reacts to event_confer_bonus, gets bonus effect
    @import("systems/player_reaction.zig").run(gs);

    // creatures react to event_take_damage, die
    @import("systems/creature_take_damage.zig").run(gs);

    // game controller reacts to 'player died' event
    @import("systems/game_controller_react.zig").run(gs);
    // player controller reacts to 'player died' event
    @import("systems/player_controller_react.zig").run(gs);

    if (i < num_frames - 1) {
      markAllEventsForRemoval(gs);
      gs.applyRemovals();
    }
  }

  // send draw commands (as events)
  @import("systems/animation_draw.zig").run(gs);
  @import("systems/creature_draw.zig").run(gs);
  @import("systems/simple_graphic_draw.zig").run(gs);

  if (gs.findFirst(C.GameController).?.render_move_boxes) {
    @import("systems/bullet_draw_box.zig").run(gs);
    @import("systems/physobject_draw_box.zig").run(gs);
    @import("systems/player_draw_box.zig").run(gs);
  }
}

// run after "middleware" (rendering, sound, etc)
pub fn gameFrameCleanup(gs: *GameSession) void {
  // clean up the draw events
  markAllEventsForRemoval(gs);
  gs.applyRemovals();
}

fn markAllEventsForRemoval(gs: *GameSession) void {
  inline for (@typeInfo(GameComponentLists).Struct.fields) |field| {
    const ComponentType = field.field_type.ComponentType;
    if (std.mem.startsWith(u8, @typeName(ComponentType), "Event")) {
      var it = gs.iter(ComponentType); while (it.next()) |object| {
        gs.markEntityForRemoval(object.entity_id);
      }
    }
  }
}
