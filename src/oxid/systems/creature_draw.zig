const levels = @import("../levels.zig");
const GameSession = @import("../game.zig").GameSession;
const constants = @import("../constants.zig");
const ConstantTypes = @import("../constant_types.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");
const Graphic = @import("../graphics.zig").Graphic;

const SystemData = struct {
    transform: *const c.Transform,
    phys: *const c.PhysObject,
    creature: *const c.Creature,
    player: ?*const c.Player,
    monster: ?*const c.Monster,
    web: ?*const c.Web,
};

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        think(gs, self);
    }
}

fn think(gs: *GameSession, self: SystemData) void {
    if (self.player) |player| {
        if (player.dying_timer > 0) {
            //_ = p.EventDraw.spawn(gs, .{ // this doesn't work
            _ = p.EventDraw.spawn(gs, c.EventDraw {
                .pos = self.transform.pos,
                .graphic =
                    if (player.dying_timer > constants.duration60(30))
                        if (alternation(u32, player.dying_timer, constants.duration60(2)))
                            Graphic.ManDying1
                        else
                            Graphic.ManDying2
                    else if (player.dying_timer > constants.duration60(20))
                        Graphic.ManDying3
                    else if (player.dying_timer > constants.duration60(10))
                        Graphic.ManDying4
                    else
                        Graphic.ManDying5,
                .transform = .identity,
                .z_index = constants.z_index_player,
            }) catch undefined;
        } else {
            drawCreature(gs, self, .{
                .graphic1 = if (player.player_number == 0) .Man1Walk1 else .Man2Walk1,
                .graphic2 = if (player.player_number == 0) .Man1Walk2 else .Man2Walk2,
                .rotates = true,
                .z_index = constants.z_index_player,
            });
        }
        return;
    }

    if (self.monster) |monster| {
        if (monster.spawning_timer > 0) {
            //_ = p.EventDraw.spawn(gs, .{ // this doesn't work
            _ = p.EventDraw.spawn(gs, c.EventDraw {
                .pos = self.transform.pos,
                .graphic =
                    if (alternation(u32, monster.spawning_timer, constants.duration60(8)))
                        .Spawn1
                    else
                        .Spawn2,
                .transform = .identity,
                .z_index = constants.z_index_enemy,
            }) catch undefined;
        } else {
            drawCreature(gs, self, switch (monster.monster_type) {
                .spider => .{
                    .graphic1 = .Spider1,
                    .graphic2 = .Spider2,
                    .rotates = true,
                    .z_index = constants.z_index_enemy,
                },
                .knight => .{
                    .graphic1 = .Knight1,
                    .graphic2 = .Knight2,
                    .rotates = true,
                    .z_index = constants.z_index_enemy,
                },
                .fast_bug => .{
                    .graphic1 = .FastBug1,
                    .graphic2 = .FastBug2,
                    .rotates = true,
                    .z_index = constants.z_index_enemy,
                },
                .squid => .{
                    .graphic1 = .Squid1,
                    .graphic2 = .Squid2,
                    .rotates = true,
                    .z_index = constants.z_index_enemy,
                },
                .juggernaut => .{
                    .graphic1 = .Juggernaut,
                    .graphic2 = .Juggernaut,
                    .rotates = false,
                    .z_index = constants.z_index_enemy,
                },
            });
        }
        return;
    }

    if (self.web) |web| {
        const graphic: Graphic =
            if (self.creature.flinch_timer > 0) .Web2 else .Web1;
        drawCreature(gs, self, .{
            .graphic1 = graphic,
            .graphic2 = graphic,
            .rotates = false,
            .z_index = constants.z_index_web,
        });
        return;
    }

    return;
}

///////////////////////////////////////

fn alternation(comptime T: type, variable: T, half_period: T) bool {
    if (half_period == 0) {
        return false;
    }
    return @mod(@divFloor(variable, half_period), 2) == 0;
}

const DrawCreatureParams = struct {
    graphic1: Graphic,
    graphic2: Graphic,
    rotates: bool,
    z_index: u32,
};

fn drawCreature(
    gs: *GameSession,
    self: SystemData,
    params: DrawCreatureParams,
) void {
    // blink during invulnerability
    if (self.creature.invulnerability_timer > 0) {
        if (alternation(u32, self.creature.invulnerability_timer,
                        constants.duration60(2))) {
            return;
        }
    }

    const xpos = switch (self.phys.facing) {
        .w, .e => self.transform.pos.x,
        .n, .s => self.transform.pos.y,
    };
    const sxpos = @divFloor(xpos, levels.subpixels_per_pixel);

    _ = p.EventDraw.spawn(gs, .{
        .pos = self.transform.pos,
        .graphic =
            // animate legs every 6 screen pixels
            if (alternation(i32, sxpos, 6))
                params.graphic1
            else
                params.graphic2,
        .transform =
            if (params.rotates)
                util.getDirTransform(self.phys.facing)
            else
                .identity,
        .z_index = params.z_index,
    }) catch undefined;
}
