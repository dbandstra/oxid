const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const Constants = @import("../constants.zig");
const levels = @import("../levels.zig");
const GameFrameContext = @import("../frame.zig").GameFrameContext;
const GameSession = @import("../game.zig").GameSession;
const util = @import("../util.zig");
const physInWall = @import("../physics.zig").physInWall;
const getLineOfFire = @import("../functions/get_line_of_fire.zig").getLineOfFire;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

const SystemData = struct {
    id: gbe.EntityId,
    creature: *const c.Creature,
    phys: *c.PhysObject,
    player: *c.Player,
    transform: *c.Transform,
};

pub fn run(gs: *GameSession, context: GameFrameContext) void {
    var it = gs.entityIter(SystemData);

    while (it.next()) |self| {
        if (self.player.spawn_anim_y_remaining > 0) {
            const dy = std.math.min(
                Constants.player_spawn_arise_speed,
                self.player.spawn_anim_y_remaining,
            );
            self.transform.pos.y -= @as(i32, dy);
            self.player.spawn_anim_y_remaining -= dy;
            continue;
        }

        if (util.decrementTimer(&self.player.dying_timer)) {
            _ = p.PlayerCorpse.spawn(gs, .{
                .pos = self.transform.pos,
            }) catch undefined;

            gs.markEntityForRemoval(self.id);
            continue;
        }

        if (self.player.dying_timer > 0) {
            if (self.player.dying_timer == Constants.duration60(30)) { // yeesh
                p.playSample(gs, .PlayerCrumble);
            }
            self.phys.speed = 0;
            self.phys.push_dir = null;
            self.player.line_of_fire = null;
            continue;
        }

        playerUpdate(gs, self);
        playerMove(gs, self);
        playerShoot(gs, self, context);
        playerUpdateLineOfFire(gs, self);
    }
}

fn playerUpdate(gs: *GameSession, self: SystemData) void {
    if (self.creature.invulnerability_timer == 0) {
        self.phys.illusory = false;
    }
}

fn playerShoot(gs: *GameSession, self: SystemData, context: GameFrameContext) void {
    if (self.player.in_shoot) {
        if (self.player.trigger_released) {
            // the player can only have a certain amount of bullets in play at a
            // time.
            // look for a bullet slot that is either null (never been used) or a
            // non-existent entity (old bullet is gone)
            if (for (self.player.bullets) |*slot| {
                if (slot.*) |bullet_id| {
                    if (gs.find(bullet_id, c.Bullet) == null) {
                        break slot;
                    }
                } else {
                    break slot;
                }
            } else null) |slot| {
                p.playSynth(gs, "Laser", audio.LaserVoice.NoteParams {
                    .freq_mul = 0.9 + 0.2 * gs.getRand().float(f32),
                    .carrier_mul = 2.0,
                    .modulator_mul = 0.5,
                    .modulator_rad = 0.5,
                });
                // spawn the bullet one quarter of a grid cell in front of the player
                const pos = self.transform.pos;
                const dir_vec = math.Direction.normal(self.phys.facing);
                const ofs = math.Vec2.scale(dir_vec, levels.subpixels_per_tile / 4);
                const bullet_pos = math.Vec2.add(pos, ofs);
                if (p.Bullet.spawn(gs, .{
                    .inflictor_player_controller_id = self.player.player_controller_id,
                    .owner_id = self.id,
                    .pos = bullet_pos,
                    .facing = self.phys.facing,
                    .bullet_type = .PlayerBullet,
                    .cluster_size = switch (self.player.attack_level) {
                        .One => 1,
                        .Two => 2,
                        .Three => 3,
                    },
                    .friendly_fire = context.friendly_fire,
                })) |bullet_entity_id| {
                    slot.* = bullet_entity_id;
                } else |_| {}
                self.player.trigger_released = false;
            }
        }
    } else {
        self.player.trigger_released = true;
    }
}

fn isTouchingWeb(gs: *GameSession, self: SystemData) bool {
    var it = gs.entityIter(struct {
        transform: *const c.Transform,
        phys: *const c.PhysObject,
        web: *const c.Web,
    });
    while (it.next()) |other| {
        if (math.boxesOverlap(
            self.transform.pos, self.phys.entity_bbox,
            other.transform.pos, other.phys.entity_bbox,
        )) {
            return true;
        }
    }
    return false;
}

fn playerMove(gs: *GameSession, self: SystemData) void {
    var move_speed = switch (self.player.speed_level) {
        .One => Constants.player_move_speed[0],
        .Two => Constants.player_move_speed[1],
        .Three => Constants.player_move_speed[2],
    };

    if (isTouchingWeb(gs, self)) {
        move_speed /= 2;
    }

    var xmove: i32 = 0;
    var ymove: i32 = 0;
    if (self.player.in_right) { xmove += 1; }
    if (self.player.in_left) { xmove -= 1; }
    if (self.player.in_down) { ymove += 1; }
    if (self.player.in_up) { ymove -= 1; }

    self.phys.speed = 0;
    self.phys.push_dir = null;

    const pos = self.transform.pos;

    if (xmove != 0) {
        const dir = if (xmove < 0) math.Direction.W else math.Direction.E;

        if (ymove == 0) {
            // only moving along x axis. try to slip around corners
            tryPush(pos, dir, move_speed, self.phys);
        } else {
            // trying to move diagonally.
            const secondary_dir = if (ymove < 0) math.Direction.N else math.Direction.S;

            // prefer to move on the x axis (arbitrary, but i had to pick something)
            if (!physInWall(self.phys, math.Vec2.add(pos, math.Direction.normal(dir)))) {
                self.phys.facing = dir;
                self.phys.speed = move_speed;
            } else if (!physInWall(self.phys, math.Vec2.add(pos, math.Direction.normal(secondary_dir)))) {
                self.phys.facing = secondary_dir;
                self.phys.speed = move_speed;
            }
        }
    } else if (ymove != 0) {
        // only moving along y axis. try to slip around corners
        const dir = if (ymove < 0) math.Direction.N else math.Direction.S;

        tryPush(pos, dir, move_speed, self.phys);
    }
}

fn tryPush(pos: math.Vec2, dir: math.Direction, speed: u31, self_phys: *c.PhysObject) void {
    const pos1 = math.Vec2.add(pos, math.Direction.normal(dir));

    if (!physInWall(self_phys, pos1)) {
        // no need to push, this direction works
        self_phys.facing = dir;
        self_phys.speed = speed;
        return;
    }

    var slip_dir: ?math.Direction = null;

    var i: i32 = 1;
    while (i < Constants.player_slip_threshold) : (i += 1) {
        if (dir == .W or dir == .E) {
            if (!physInWall(self_phys, math.Vec2.init(pos1.x, pos1.y - i))) {
                slip_dir = .N;
                break;
            }
            if (!physInWall(self_phys, math.Vec2.init(pos1.x, pos1.y + i))) {
                slip_dir = .S;
                break;
            }
        }
        if (dir == .N or dir == .S) {
            if (!physInWall(self_phys, math.Vec2.init(pos1.x - i, pos1.y))) {
                slip_dir = .W;
                break;
            }
            if (!physInWall(self_phys, math.Vec2.init(pos1.x + i, pos1.y))) {
                slip_dir = .E;
                break;
            }
        }
    }

    if (slip_dir) |slipdir| {
        self_phys.facing = slipdir;
        self_phys.speed = speed;
        self_phys.push_dir = dir;
    }
}

fn playerUpdateLineOfFire(gs: *GameSession, self: SystemData) void {
    // create a box that represents the path of a bullet fired by the player in
    // the current frame, ignoring monsters.
    // certain monster behaviours will use this in order to try to get out of the
    // way
    // TODO - do this before calling playerShoot. give bullets a line_of_fire as
    // well, and make monsters avoid those too
    const pos = self.transform.pos;
    const dir_vec = math.Direction.normal(self.phys.facing);
    const ofs = math.Vec2.scale(dir_vec, levels.subpixels_per_tile / 4);
    const bullet_pos = math.Vec2.add(pos, ofs);

    self.player.line_of_fire = getLineOfFire(bullet_pos, p.bullet_bbox, self.phys.facing);
}
