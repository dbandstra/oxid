const Draw = @import("../../draw.zig");
const Math = @import("../../math.zig");
const Gbe = @import("../../gbe.zig");
const GbeSystem = @import("../../gbe_system.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const ConstantTypes = @import("../constant_types.zig");
const C = @import("../components.zig");
const Prototypes = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;

const SystemData = struct{
  transform: *const C.Transform,
  phys: *const C.PhysObject,
  creature: *const C.Creature,
  player: ?*const C.Player,
  monster: ?*const C.Monster,
  web: ?*const C.Web,
};

pub const run = GbeSystem.build(GameSession, SystemData, think);

// helper
fn alternation(comptime T: type, variable: T, half_period: T) bool {
  return @mod(@divFloor(variable, half_period), 2) == 0;
}

fn think(gs: *GameSession, self: SystemData) bool {
  var graphic1: ?Graphic = null;
  var graphic2: ?Graphic = null;
  var rotates: ?bool = null;
  var z_index: ?u32 = null;

  if (self.player) |player| {
    if (player.dying_timer > 0) {
      // death animation?
      _ = Prototypes.EventDraw.spawn(gs, C.EventDraw{
        .pos = self.transform.pos,
        .graphic =
          if (player.dying_timer > 30)
            if (alternation(u32, player.dying_timer, 2))
              Graphic.ManDying1
            else
              Graphic.ManDying2
          else if (player.dying_timer > 20)
            Graphic.ManDying3
          else if (player.dying_timer > 10)
            Graphic.ManDying4
          else
            Graphic.ManDying5,
        .transform = Draw.Transform.Identity,
        .z_index = Constants.ZIndexPlayer,
      });
      return true;
    }

    graphic1 = Graphic.Man1;
    graphic2 = Graphic.Man2;
    rotates = true;
    z_index = Constants.ZIndexPlayer;
  }

  // if monster is spawning, show the spawning effect
  if (self.monster) |monster| {
    if (monster.spawning_timer > 0) {
      _ = Prototypes.EventDraw.spawn(gs, C.EventDraw{
        .pos = self.transform.pos,
        .graphic =
          if (alternation(u32, monster.spawning_timer, 8))
            Graphic.Spawn1
          else
            Graphic.Spawn2,
        .transform = Draw.Transform.Identity,
        .z_index = Constants.ZIndexEnemy,
      });
      return true;
    }

    switch (monster.monster_type) {
      ConstantTypes.MonsterType.Spider => {
        graphic1 = Graphic.Spider1;
        graphic2 = Graphic.Spider2;
        rotates = true;
      },
      ConstantTypes.MonsterType.Knight => {
        graphic1 = Graphic.Knight1;
        graphic2 = Graphic.Knight2;
        rotates = true;
      },
      ConstantTypes.MonsterType.FastBug => {
        graphic1 = Graphic.FastBug1;
        graphic2 = Graphic.FastBug2;
        rotates = true;
      },
      ConstantTypes.MonsterType.Squid => {
        graphic1 = Graphic.Squid1;
        graphic2 = Graphic.Squid2;
        rotates = true;
      },
      ConstantTypes.MonsterType.Juggernaut => {
        graphic1 = Graphic.Juggernaut;
        graphic2 = Graphic.Juggernaut;
        rotates = false;
      },
    }
    z_index = Constants.ZIndexEnemy;
  }

  if (self.web) |web| {
    if (self.creature.flinch_timer > 0) {
      graphic1 = Graphic.Web2;
      graphic2 = Graphic.Web2;
    } else {
      graphic1 = Graphic.Web1;
      graphic2 = Graphic.Web1;
    }
    rotates = false;
    z_index = Constants.ZIndexWeb;
  }

  // blink during invulnerability
  if (self.creature.invulnerability_timer > 0) {
    if (alternation(u32, self.creature.invulnerability_timer, 2)) {
      return true;
    }
  }

  const xpos = switch (self.phys.facing) {
    Math.Direction.W, Math.Direction.E => self.transform.pos.x,
    Math.Direction.N, Math.Direction.S => self.transform.pos.y,
  };
  const sxpos = @divFloor(xpos, Math.SUBPIXELS);

  const g1 = graphic1 orelse return true;
  const g2 = graphic2 orelse return true;
  const r = rotates orelse return true;
  const z = z_index orelse return true;

  _ = Prototypes.EventDraw.spawn(gs, C.EventDraw{
    .pos = self.transform.pos,
    // animate legs every 6 screen pixels
    .graphic = if (alternation(i32, sxpos, 6)) g1 else g2,
    .transform =
      if (r)
        GameUtil.getDirTransform(self.phys.facing)
      else
        Draw.Transform.Identity,
    .z_index = z,
  });
  return true;
}
