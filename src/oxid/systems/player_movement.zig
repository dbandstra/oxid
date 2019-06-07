const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const boxesOverlap = @import("../../common/boxes_overlap.zig").boxesOverlap;
const Constants = @import("../constants.zig");
const GRIDSIZE_SUBPIXELS = @import("../level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("../level.zig").LEVEL;
const GameSession = @import("../game.zig").GameSession;
const GameUtil = @import("../util.zig");
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

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) bool {
    if (self.player.spawn_anim_y_remaining > 0) {
        const dy = std.math.min(8, self.player.spawn_anim_y_remaining);
        self.transform.pos.y -= i32(dy);
        self.player.spawn_anim_y_remaining -= dy;
        return true;
    } else if (GameUtil.decrementTimer(&self.player.dying_timer)) {
        _ = p.PlayerCorpse.spawn(gs, p.PlayerCorpse.Params{
            .pos = self.transform.pos,
        }) catch undefined;
        return false;
    } else if (self.player.dying_timer > 0) {
        if (self.player.dying_timer == 30) { // yeesh
            p.playSample(gs, .PlayerCrumble);
        }
        self.phys.speed = 0;
        self.phys.push_dir = null;
        self.player.line_of_fire = null;
    } else {
        playerUpdate(gs, self);
        playerMove(gs, self);
        playerShoot(gs, self);
        playerUpdateLineOfFire(gs, self);
    }
    return true;
}

fn playerUpdate(gs: *GameSession, self: SystemData) void {
    if (self.creature.invulnerability_timer == 0) {
        self.phys.illusory = false;
    }
}

fn playerShoot(gs: *GameSession, self: SystemData) void {
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
                p.playSynth(gs, audio.LaserVoice.NoteParams {
                    .freq_mul = 0.9 + 0.2 * gs.getRand().float(f32),
                    .carrier_mul = 2.0,
                    .modulator_mul = 0.5,
                    .modulator_rad = 0.5,
                });
                // spawn the bullet one quarter of a grid cell in front of the player
                const pos = self.transform.pos;
                const dir_vec = math.Direction.normal(self.phys.facing);
                const ofs = math.Vec2.scale(dir_vec, GRIDSIZE_SUBPIXELS / 4);
                const bullet_pos = math.Vec2.add(pos, ofs);
                if (p.Bullet.spawn(gs, p.Bullet.Params{
                    .inflictor_player_controller_id = self.player.player_controller_id,
                    .owner_id = self.id,
                    .pos = bullet_pos,
                    .facing = self.phys.facing,
                    .bullet_type = p.Bullet.BulletType.PlayerBullet,
                    .cluster_size = switch (self.player.attack_level) {
                        c.Player.AttackLevel.One => u32(1),
                        c.Player.AttackLevel.Two => u32(2),
                        c.Player.AttackLevel.Three => u32(3),
                    },
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
    var it = gs.iter(c.Web); while (it.next()) |object| {
        const transform = gs.find(object.entity_id, c.Transform) orelse continue;
        const phys = gs.find(object.entity_id, c.PhysObject) orelse continue;

        if (boxesOverlap(
            self.transform.pos, self.phys.entity_bbox,
            transform.pos, phys.entity_bbox,
        )) {
            return true;
        }
    }

    return false;
}

fn playerMove(gs: *GameSession, self: SystemData) void {
    var move_speed = switch (self.player.speed_level) {
        c.Player.SpeedLevel.One => Constants.PlayerMoveSpeed[0],
        c.Player.SpeedLevel.Two => Constants.PlayerMoveSpeed[1],
        c.Player.SpeedLevel.Three => Constants.PlayerMoveSpeed[2],
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

fn tryPush(pos: math.Vec2, dir: math.Direction, speed: i32, self_phys: *c.PhysObject) void {
    const pos1 = math.Vec2.add(pos, math.Direction.normal(dir));

    if (!physInWall(self_phys, pos1)) {
        // no need to push, this direction works
        self_phys.facing = dir;
        self_phys.speed = speed;
        return;
    }

    var slip_dir: ?math.Direction = null;

    var i: i32 = 1;
    while (i < Constants.PlayerSlipThreshold) : (i += 1) {
        if (dir == math.Direction.W or dir == math.Direction.E) {
            if (!physInWall(self_phys, math.Vec2.init(pos1.x, pos1.y - i))) {
                slip_dir = math.Direction.N;
                break;
            }
            if (!physInWall(self_phys, math.Vec2.init(pos1.x, pos1.y + i))) {
                slip_dir = math.Direction.S;
                break;
            }
        }
        if (dir == math.Direction.N or dir == math.Direction.S) {
            if (!physInWall(self_phys, math.Vec2.init(pos1.x - i, pos1.y))) {
                slip_dir = math.Direction.W;
                break;
            }
            if (!physInWall(self_phys, math.Vec2.init(pos1.x + i, pos1.y))) {
                slip_dir = math.Direction.E;
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
    const ofs = math.Vec2.scale(dir_vec, GRIDSIZE_SUBPIXELS / 4);
    const bullet_pos = math.Vec2.add(pos, ofs);

    self.player.line_of_fire = getLineOfFire(bullet_pos, p.bullet_bbox, self.phys.facing);
}
