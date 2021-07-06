const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");
const graphics = @import("../graphics.zig");

pub fn run(gs: *game.Session, ctx: game.FrameContext) void {
    drawSimpleGraphics(gs);
    drawAnimations(gs);
    drawCreatures(gs, ctx);
}

fn drawSimpleGraphics(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: ?*const c.PhysObject,
        simple_graphic: *const c.SimpleGraphic,
    });
    while (it.next()) |self| {
        p.spawnEventDraw(gs, .{
            .pos = self.transform.pos,
            .graphic = self.simple_graphic.graphic,
            .transform = if (self.simple_graphic.directional)
                if (self.phys) |phys|
                    util.getDirTransform(phys.facing)
                else
                    .identity
            else
                .identity,
            .z_index = self.simple_graphic.z_index,
            .alpha = 255,
        });
    }
}

fn drawAnimations(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        animation: *const c.Animation,
    });
    while (it.next()) |self| {
        const anim = graphics.getSimpleAnim(self.animation.simple_anim);
        p.spawnEventDraw(gs, .{
            .pos = self.transform.pos,
            .graphic = anim.frames[self.animation.frame_index],
            .transform = .identity,
            .z_index = self.animation.z_index,
            .alpha = 255,
        });
    }
}

fn drawCreatures(gs: *game.Session, ctx: game.FrameContext) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        creature: *const c.Creature,
        player: ?*const c.Player,
        monster: ?*const c.Monster,
        web: ?*const c.Web,
    });
    while (it.next()) |self| {
        var alpha: u8 = 255;
        if (self.creature.invulnerability_timer > 0) {
            if (ctx.fast_forward) {
                alpha = 100;
            } else if (alternation(u32, self.creature.invulnerability_timer, constants.duration60(2))) {
                continue;
            }
        }
        if (self.player) |player|
            drawPlayer(gs, self.transform.pos, self.phys.facing, player, alpha);
        if (self.monster) |monster|
            drawMonster(gs, self.transform.pos, self.phys.facing, monster, alpha);
        if (self.web) |web|
            drawWeb(gs, self.transform.pos, self.creature, alpha);
    }
}

fn drawPlayer(
    gs: *game.Session,
    pos: math.Vec2,
    facing: math.Direction,
    player: *const c.Player,
    alpha: u8,
) void {
    if (player.dying_timer > 0) {
        const graphic: graphics.Graphic = blk: {
            if (player.dying_timer > constants.duration60(30)) {
                if (player.oxygen == 0) {
                    switch (player.color) {
                        .yellow => break :blk .man1_choke,
                        .green => break :blk .man2_choke,
                    }
                }
                if (alternation(u32, player.dying_timer, constants.duration60(2))) {
                    break :blk .man_dying1;
                } else {
                    break :blk .man_dying2;
                }
            }
            if (player.dying_timer > constants.duration60(20))
                break :blk .man_dying3;
            if (player.dying_timer > constants.duration60(10))
                break :blk .man_dying4;
            break :blk .man_dying5;
        };
        p.spawnEventDraw(gs, .{
            .pos = pos,
            .graphic = graphic,
            .transform = .identity,
            .z_index = constants.z_index_player,
            .alpha = alpha,
        });
        return;
    }
    p.spawnEventDraw(gs, .{
        .pos = pos,
        .graphic = walkFrame(pos, facing, switch (player.color) {
            .yellow => .{ .man1_walk1, .man1_walk2 },
            .green => .{ .man2_walk1, .man2_walk2 },
        }),
        .transform = util.getDirTransform(facing),
        .z_index = constants.z_index_player,
        .alpha = alpha,
    });
}

fn drawMonster(
    gs: *game.Session,
    pos: math.Vec2,
    facing: math.Direction,
    monster: *const c.Monster,
    alpha: u8,
) void {
    if (monster.spawning_timer > 0) {
        p.spawnEventDraw(gs, .{
            .pos = pos,
            .graphic = if (alternation(u32, monster.spawning_timer, constants.duration60(8)))
                .spawn1
            else
                .spawn2,
            .transform = .identity,
            .z_index = constants.z_index_enemy,
            .alpha = alpha,
        });
        return;
    }
    p.spawnEventDraw(gs, .{
        .pos = pos,
        .graphic = switch (monster.monster_type) {
            .spider => walkFrame(pos, facing, .{ .spider1, .spider2 }),
            .knight => walkFrame(pos, facing, .{ .knight1, .knight2 }),
            .fast_bug => walkFrame(pos, facing, .{ .fast_bug1, .fast_bug2 }),
            .squid => walkFrame(pos, facing, .{ .squid1, .squid2 }),
            .juggernaut => .juggernaut,
        },
        .transform = util.getDirTransform(facing),
        .z_index = constants.z_index_enemy,
        .alpha = alpha,
    });
}

fn drawWeb(gs: *game.Session, pos: math.Vec2, creature: *const c.Creature, alpha: u8) void {
    p.spawnEventDraw(gs, .{
        .pos = pos,
        .graphic = if (creature.flinch_timer > 0) .web2 else .web1,
        .transform = .identity,
        .z_index = constants.z_index_web,
        .alpha = alpha,
    });
}

fn alternation(comptime T: type, variable: T, half_period: T) bool {
    if (half_period == 0)
        return false;
    return @mod(@divFloor(variable, half_period), 2) == 0;
}

fn walkFrame(pos: math.Vec2, facing: math.Direction, frames: [2]graphics.Graphic) graphics.Graphic {
    const xpos = switch (facing) {
        .w, .e => pos.x,
        .n, .s => pos.y,
    };
    const sxpos = @divFloor(xpos, levels.subpixels_per_pixel);
    if (alternation(i32, sxpos, 6)) {
        return frames[0];
    } else {
        return frames[1];
    }
}
