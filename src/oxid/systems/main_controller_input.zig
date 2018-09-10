const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const input = @import("../input.zig");

const SystemData = struct{
  mc: *C.MainController,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
  if (self.mc.game_running_state) |*grs| {
    if (grs.exit_dialog_open) {
      handleExitDialogInput(gs, self.mc, grs);
    } else {
      handleGameRunningInput(gs, grs);
    }
  } else {
    handleMainMenuInput(gs, self.mc);
  }
  return true;
}

fn handleExitDialogInput(gs: *GameSession, mc: *C.MainController, grs: *C.MainController.GameRunningState) void {
  var it = gs.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
      input.Command.Escape,
      input.Command.No => {
        if (event.data.down) {
          grs.exit_dialog_open = false;
        }
      },
      input.Command.Yes => {
        if (event.data.down) {
          leaveGame(gs, mc);
        }
      },
      else => {},
    }
  }
}

fn handleGameRunningInput(gs: *GameSession, grs: *C.MainController.GameRunningState) void {
  var it = gs.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
      input.Command.Escape => {
        if (event.data.down) {
          grs.exit_dialog_open = true;
        }
      },
      input.Command.ToggleDrawBoxes => {
        if (event.data.down) {
          grs.render_move_boxes = !grs.render_move_boxes;
        }
      },
      else => {},
    }
  }
}

fn handleMainMenuInput(gs: *GameSession, mc: *C.MainController) void {
  var it = gs.iter(C.EventInput); while (it.next()) |event| {
    switch (event.data.command) {
      input.Command.Escape => {
        if (event.data.down) {
          _ = Prototypes.EventQuit.spawn(gs, C.EventQuit{ .unused = 0 });
        }
      },
      input.Command.Shoot => {
        if (event.data.down) {
          startGame(gs, mc);
        }
      },
      else => {},
    }
  }
}

fn startGame(gs: *GameSession, mc: *C.MainController) void {
  mc.game_running_state = C.MainController.GameRunningState{
    .render_move_boxes = false,
    .exit_dialog_open = false,
  };

  _ = Prototypes.GameController.spawn(gs);
  _ = Prototypes.PlayerController.spawn(gs);
}

fn leaveGame(gs: *GameSession, mc: *C.MainController) void {
  mc.game_running_state = null;

  // remove all entities except the MainController
  inline for (@typeInfo(GameSession.ComponentListsType).Struct.fields) |field| {
    const ComponentType = field.field_type.ComponentType;
    if (ComponentType != C.MainController) {
      var it = gs.iter(ComponentType); while (it.next()) |object| {
        gs.markEntityForRemoval(object.entity_id);
      }
    }
  }
}
