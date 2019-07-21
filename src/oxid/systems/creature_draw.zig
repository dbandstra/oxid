const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");
const GameSession = @import("../game.zig").GameSession;
const Constants = @import("../constants.zig");
const ConstantTypes = @import("../constant_types.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const GameUtil = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;

const SystemData = struct{
    transform: *const c.Transform,
    phys: *const c.PhysObject,
    creature: *const c.Creature,
    player: ?*const c.Player,
    monster: ?*const c.Monster,
    web: ?*const c.Web,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.player) |player| {
        if (player.dying_timer > 0) {
            _ = p.EventDraw.spawn(gs, c.EventDraw {
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
                .transform = .Identity,
                .z_index = Constants.ZIndexPlayer,
            }) catch undefined;
        } else {
            drawCreature(gs, self, DrawCreatureParams {
                .graphic1 = .Man1,
                .graphic2 = .Man2,
                .rotates = true,
                .z_index = Constants.ZIndexPlayer,
            });
        }
        return true;
    }

    if (self.monster) |monster| {
        if (monster.spawning_timer > 0) {
            _ = p.EventDraw.spawn(gs, c.EventDraw {
                .pos = self.transform.pos,
                .graphic =
                    if (alternation(u32, monster.spawning_timer, 8))
                        Graphic.Spawn1
                    else
                        Graphic.Spawn2,
                .transform = .Identity,
                .z_index = Constants.ZIndexEnemy,
            }) catch undefined;
        } else {
            drawCreature(gs, self, switch (monster.monster_type) {
                ConstantTypes.MonsterType.Spider => DrawCreatureParams {
                    .graphic1 = .Spider1,
                    .graphic2 = .Spider2,
                    .rotates = true,
                    .z_index = Constants.ZIndexEnemy,
                },
                ConstantTypes.MonsterType.Knight => DrawCreatureParams {
                    .graphic1 = .Knight1,
                    .graphic2 = .Knight2,
                    .rotates = true,
                    .z_index = Constants.ZIndexEnemy,
                },
                ConstantTypes.MonsterType.FastBug => DrawCreatureParams {
                    .graphic1 = .FastBug1,
                    .graphic2 = .FastBug2,
                    .rotates = true,
                    .z_index = Constants.ZIndexEnemy,
                },
                ConstantTypes.MonsterType.Squid => DrawCreatureParams {
                    .graphic1 = .Squid1,
                    .graphic2 = .Squid2,
                    .rotates = true,
                    .z_index = Constants.ZIndexEnemy,
                },
                ConstantTypes.MonsterType.Juggernaut => DrawCreatureParams {
                    .graphic1 = .Juggernaut,
                    .graphic2 = .Juggernaut,
                    .rotates = false,
                    .z_index = Constants.ZIndexEnemy,
                },
            });
        }
        return true;
    }

    if (self.web) |web| {
        const graphic = if (self.creature.flinch_timer > 0) Graphic.Web2 else Graphic.Web1;
        drawCreature(gs, self, DrawCreatureParams {
            .graphic1 = graphic,
            .graphic2 = graphic,
            .rotates = false,
            .z_index = Constants.ZIndexWeb,
        });
        return true;
    }

    return true;
}

///////////////////////////////////////

fn alternation(comptime T: type, variable: T, half_period: T) bool {
    return @mod(@divFloor(variable, half_period), 2) == 0;
}

const DrawCreatureParams = struct{
    graphic1: Graphic,
    graphic2: Graphic,
    rotates: bool,
    z_index: u32,
};

fn drawCreature(gs: *GameSession, self: SystemData, params: DrawCreatureParams) void {
    // blink during invulnerability
    if (self.creature.invulnerability_timer > 0) {
        if (alternation(u32, self.creature.invulnerability_timer, 2)) {
            return;
        }
    }

    const xpos = switch (self.phys.facing) {
        .W, .E => self.transform.pos.x,
        .N, .S => self.transform.pos.y,
    };
    const sxpos = @divFloor(xpos, levels.SUBPIXELS_PER_PIXEL);

    _ = p.EventDraw.spawn(gs, c.EventDraw {
        .pos = self.transform.pos,
        // animate legs every 6 screen pixels
        .graphic = if (alternation(i32, sxpos, 6)) params.graphic1 else params.graphic2,
        .transform =
            if (params.rotates)
                GameUtil.getDirTransform(self.phys.facing)
            else
                .Identity,
        .z_index = params.z_index,
    }) catch undefined;
}
