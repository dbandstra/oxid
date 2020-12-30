const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");
const graphics = @import("../graphics.zig");

pub fn run(gs: *game.Session) void {
    drawSimpleGraphics(gs);
    drawAnimations(gs);
    drawPlayers(gs);
    drawMonsters(gs);
    drawWebs(gs);
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
        });
    }
}

fn drawPlayers(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        creature: *const c.Creature,
        player: *const c.Player,
    });
    while (it.next()) |self| {
        if (self.player.dying_timer > 0) {
            p.spawnEventDraw(gs, .{
                .pos = self.transform.pos,
                .graphic = if (self.player.dying_timer > constants.duration60(30))
                    if (alternation(u32, self.player.dying_timer, constants.duration60(2)))
                        graphics.Graphic.man_dying1
                    else
                        graphics.Graphic.man_dying2
                else if (self.player.dying_timer > constants.duration60(20))
                    graphics.Graphic.man_dying3
                else if (self.player.dying_timer > constants.duration60(10))
                    graphics.Graphic.man_dying4
                else
                    graphics.Graphic.man_dying5,
                .transform = .identity,
                .z_index = constants.z_index_player,
            });
            continue;
        }
        if (invulnerabilityBlink(self.creature.invulnerability_timer))
            continue;
        const pos = self.transform.pos;
        const facing = self.phys.facing;
        p.spawnEventDraw(gs, .{
            .pos = pos,
            .graphic = walkFrame(pos, facing, switch (self.player.player_number) {
                0 => .{ .man1_walk1, .man1_walk2 },
                else => .{ .man2_walk1, .man2_walk2 },
            }),
            .transform = util.getDirTransform(facing),
            .z_index = constants.z_index_player,
        });
    }
}

fn drawMonsters(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        creature: *const c.Creature,
        monster: *const c.Monster,
    });
    while (it.next()) |self| {
        if (self.monster.spawning_timer > 0) {
            p.spawnEventDraw(gs, .{
                .pos = self.transform.pos,
                .graphic = if (alternation(u32, self.monster.spawning_timer, constants.duration60(8)))
                    .spawn1
                else
                    .spawn2,
                .transform = .identity,
                .z_index = constants.z_index_enemy,
            });
            continue;
        }
        if (invulnerabilityBlink(self.creature.invulnerability_timer))
            continue;
        const pos = self.transform.pos;
        const facing = self.phys.facing;
        p.spawnEventDraw(gs, .{
            .pos = pos,
            .graphic = switch (self.monster.monster_type) {
                .spider => walkFrame(pos, facing, .{ .spider1, .spider2 }),
                .knight => walkFrame(pos, facing, .{ .knight1, .knight2 }),
                .fast_bug => walkFrame(pos, facing, .{ .fast_bug1, .fast_bug2 }),
                .squid => walkFrame(pos, facing, .{ .squid1, .squid2 }),
                .juggernaut => .juggernaut,
            },
            .transform = util.getDirTransform(facing),
            .z_index = constants.z_index_enemy,
        });
    }
}

fn drawWebs(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        creature: *const c.Creature,
        web: *const c.Web,
    });
    while (it.next()) |self| {
        p.spawnEventDraw(gs, .{
            .pos = self.transform.pos,
            .graphic = if (self.creature.flinch_timer > 0) .web2 else .web1,
            .transform = .identity,
            .z_index = constants.z_index_web,
        });
    }
}

fn alternation(comptime T: type, variable: T, half_period: T) bool {
    if (half_period == 0)
        return false;
    return @mod(@divFloor(variable, half_period), 2) == 0;
}

fn invulnerabilityBlink(timer: u32) bool {
    return timer > 0 and alternation(u32, timer, constants.duration60(2));
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
