const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");
const GameSession = @import("../game.zig").GameSession;
const util = @import("../util.zig");
const physInWall = @import("../physics.zig").physInWall;
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const audio = @import("../audio.zig");

const SystemData = struct {
    id: gbe.EntityId,
    creature: *c.Creature,
    phys: *c.PhysObject,
    monster: *c.Monster,
    transform: *const c.Transform,
    voice_laser: ?*c.VoiceLaser,
};

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        if (util.decrementTimer(&self.monster.spawning_timer)) {
            self.creature.hit_points = self.monster.full_hit_points;
        } else if (self.monster.spawning_timer > 0) {
            self.phys.speed = 0;
            self.phys.push_dir = null;
        } else {
            monsterMove(gs, self);
            if (self.monster.can_shoot or self.monster.can_drop_webs) {
                monsterAttack(gs, self);
            }
        }
    }
}

fn monsterMove(gs: *GameSession, self: SystemData) void {
    const gc = gs.ecs.findFirstComponent(c.GameController).?;

    self.phys.push_dir = null;

    if (gc.freeze_monsters_timer > 0 or self.creature.flinch_timer > 0) {
        self.phys.speed = 0;
        return;
    }

    if (gc.monster_count < 5) {
        self.monster.personality = .chase;
    }

    const monster_values = constants.getMonsterValues(self.monster.monster_type);
    const move_speed = if (gc.enemy_speed_level < monster_values.move_speed.len)
        monster_values.move_speed[gc.enemy_speed_level]
    else
        monster_values.move_speed[monster_values.move_speed.len - 1];

    // look ahead for corners
    const pos = self.transform.pos;
    const fwd = math.Direction.normal(self.phys.facing);
    const left = math.Direction.rotateCcw(self.phys.facing);
    const right = math.Direction.rotateCw(self.phys.facing);
    const left_normal = math.Direction.normal(left);
    const right_normal = math.Direction.normal(right);

    var can_go_forward = true;
    var can_go_left = false;
    var can_go_right = false;

    if (physInWall(self.phys, pos)) {
        // stuck in a wall
        return;
    }

    var i: u31 = 0;
    while (i < move_speed) : (i += 1) {
        const new_pos = math.Vec2.add(pos, math.Vec2.scale(fwd, i));
        const left_pos = math.Vec2.add(new_pos, left_normal);
        const right_pos = math.Vec2.add(new_pos, right_normal);

        if (i > 0 and physInWall(self.phys, new_pos)) {
            can_go_forward = false;
        }
        if (!physInWall(self.phys, left_pos)) {
            can_go_left = true;
        }
        if (!physInWall(self.phys, right_pos)) {
            can_go_right = true;
        }
    }

    // if monster is in a player's line of fire, try to get out of the way
    if (isInLineOfFire(gs, self)) |bullet_dir| {
        const bullet_x_axis = switch (bullet_dir) {
            .n, .s => false,
            .w, .e => true,
        };
        const self_x_axis = switch (self.phys.facing) {
            .n, .s => false,
            .w, .e => true,
        };
        if (bullet_x_axis == self_x_axis) {
            // bullet is travelling along the same axis as me. prefer to make a turn
            if (can_go_left or can_go_right) {
                can_go_forward = false;
            }
        } else {
            // bullet is travelling on a perpendicular axis. prefer to go forward
            if (can_go_forward) {
                can_go_left = false;
                can_go_right = false;
            }
        }
    }

    if (chooseTurn(gs, self.monster.personality, pos, self.phys.facing, can_go_forward, can_go_left, can_go_right)) |dir| {
        self.phys.push_dir = dir;
    }

    self.phys.speed = move_speed;
}

fn monsterAttack(gs: *GameSession, self: SystemData) void {
    const gc = gs.ecs.findFirstComponent(c.GameController).?;
    if (gc.freeze_monsters_timer > 0) {
        return;
    }
    if (self.monster.next_attack_timer > 0) {
        self.monster.next_attack_timer -= 1;
    } else {
        if (self.monster.can_shoot) {
            if (self.voice_laser) |voice_laser| {
                voice_laser.params = .{
                    .freq_mul = 0.9 + 0.2 * gs.getRand().float(f32),
                    .carrier_mul = 4.0,
                    .modulator_mul = 0.125,
                    .modulator_rad = 1.0,
                };
            }
            // spawn the bullet one quarter of a grid cell in front of the monster
            const pos = self.transform.pos;
            const dir_vec = math.Direction.normal(self.phys.facing);
            const ofs = math.Vec2.scale(dir_vec, levels.subpixels_per_tile / 4);
            const bullet_pos = math.Vec2.add(pos, ofs);
            _ = p.Bullet.spawn(gs, .{
                .inflictor_player_controller_id = null,
                .owner_id = self.id,
                .pos = bullet_pos,
                .facing = self.phys.facing,
                .bullet_type = .monster_bullet,
                .cluster_size = 1,
                .friendly_fire = false, // this value is irrelevant for monster bullets
            }) catch undefined;
        } else if (self.monster.can_drop_webs) {
            _ = p.Web.spawn(gs, .{
                .pos = self.transform.pos,
            }) catch undefined;
        }
        self.monster.next_attack_timer =
            constants.duration60(gs.getRand().intRangeLessThan(u31, 75, 400));
    }
}

// this function needs more args if this is going to be any good
fn getChaseTarget(gs: *GameSession, self_pos: math.Vec2) ?math.Vec2 {
    // choose the nearest player
    var nearest: ?math.Vec2 = null;
    var nearest_dist: u32 = 0;
    var it = gs.ecs.iter(struct {
        player: *const c.Player,
        transform: *const c.Transform,
    });
    while (it.next()) |entry| {
        const dist = math.Vec2.manhattanDistance(entry.transform.pos, self_pos);
        if (nearest == null or dist < nearest_dist) {
            nearest = entry.transform.pos;
            nearest_dist = dist;
        }
    }
    return nearest;
}

fn chooseTurn(
    gs: *GameSession,
    personality: c.Monster.Personality,
    pos: math.Vec2,
    facing: math.Direction,
    can_go_forward: bool,
    can_go_left: bool,
    can_go_right: bool,
) ?math.Direction {
    const left = math.Direction.rotateCcw(facing);
    const right = math.Direction.rotateCw(facing);

    var choices = util.Choices.init();

    if (personality == .chase) {
        if (getChaseTarget(gs, pos)) |target_pos| {
            const fwd = math.Direction.normal(facing);
            const left_normal = math.Direction.normal(left);
            const right_normal = math.Direction.normal(right);

            const forward_point = math.Vec2.add(pos, math.Vec2.scale(fwd, levels.subpixels_per_tile));
            const left_point = math.Vec2.add(pos, math.Vec2.scale(left_normal, levels.subpixels_per_tile));
            const right_point = math.Vec2.add(pos, math.Vec2.scale(right_normal, levels.subpixels_per_tile));

            const forward_point_dist = math.Vec2.manhattanDistance(forward_point, target_pos);
            const left_point_dist = math.Vec2.manhattanDistance(left_point, target_pos);
            const right_point_dist = math.Vec2.manhattanDistance(right_point, target_pos);

            if (can_go_forward) {
                choices.add(facing, forward_point_dist);
            }
            if (can_go_left) {
                choices.add(left, left_point_dist);
            }
            if (can_go_right) {
                choices.add(right, right_point_dist);
            }

            if (choices.choose()) |best_direction| {
                if (best_direction != facing) {
                    return best_direction;
                }
            }

            return null;
        }
    }

    // wandering
    if (can_go_forward) {
        choices.add(facing, 2);
    }
    if (can_go_left) {
        choices.add(left, 1);
    }
    if (can_go_right) {
        choices.add(right, 1);
    }
    const total_score = blk: {
        var total: u32 = 0;
        for (choices.choices[0..choices.num_choices]) |choice| {
            total += choice.score;
        }
        break :blk total;
    };
    if (total_score > 0) {
        var r = gs.getRand().intRangeLessThan(u32, 0, total_score);
        for (choices.choices[0..choices.num_choices]) |choice| {
            if (r < choice.score) {
                return choice.direction;
            } else {
                r -= choice.score;
            }
        }
    }

    return null;
}

// return the direction a bullet would be fired, or null if not in the line of
// fire
fn isInLineOfFire(gs: *GameSession, self: SystemData) ?math.Direction {
    const self_absbox = math.BoundingBox.move(self.phys.entity_bbox, self.transform.pos);

    var it = gs.ecs.iter(struct {
        player: *const c.Player,
        phys: *const c.PhysObject,
    });
    while (it.next()) |entry| {
        const box = entry.player.line_of_fire orelse continue;
        if (!math.absBoxesOverlap(self_absbox, box)) continue;
        return entry.phys.facing;
    }

    var it2 = gs.ecs.iter(struct {
        bullet: *const c.Bullet,
        phys: *const c.PhysObject,
    });
    while (it2.next()) |entry| {
        const box = entry.bullet.line_of_fire orelse continue;
        if (!math.absBoxesOverlap(self_absbox, box)) continue;
        return entry.phys.facing;
    }

    return null;
}
