const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const levels = @import("../levels.zig");
const game = @import("../game.zig");
const util = @import("../util.zig");
const physics = @import("../physics.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    creature: *c.Creature,
    phys: *c.PhysObject,
    monster: *c.Monster,
    transform: *const c.Transform,
    voice_laser: ?*c.VoiceLaser,
};

pub fn run(gs: *game.Session) void {
    const gc = gs.ecs.findFirstComponent(c.GameController) orelse return;

    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        if (self.monster.spawning_timer > 0) {
            self.monster.spawning_timer -= 1;
            if (self.monster.spawning_timer == 0) {
                // completed the spawning animation
                self.creature.hit_points = self.monster.full_hit_points;
            } else {
                self.phys.speed = 0;
                self.phys.push_dir = null;
            }
            continue;
        }

        monsterMove(gs, gc, self);

        if (self.monster.can_shoot) {
            monsterAttack(gs, gc, self, .shoot);
        } else if (constants.getMonsterValues(self.monster.monster_type).can_drop_webs) {
            monsterAttack(gs, gc, self, .drop_web);
        }
    }
}

fn monsterMove(gs: *game.Session, gc: *c.GameController, self: SystemData) void {
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
    const fwd = math.getNormal(self.phys.facing);
    const left = math.rotateCCW(self.phys.facing);
    const right = math.rotateCW(self.phys.facing);
    const left_normal = math.getNormal(left);
    const right_normal = math.getNormal(right);

    var can_go_forward = true;
    var can_go_left = false;
    var can_go_right = false;

    if (physics.inWall(self.phys, pos)) {
        // stuck in a wall
        return;
    }

    var i: u31 = 0;
    while (i < move_speed) : (i += 1) {
        const new_pos = math.vec2Add(pos, math.vec2Scale(fwd, i));
        const left_pos = math.vec2Add(new_pos, left_normal);
        const right_pos = math.vec2Add(new_pos, right_normal);

        if (i > 0 and physics.inWall(self.phys, new_pos)) {
            can_go_forward = false;
        }
        if (!physics.inWall(self.phys, left_pos)) {
            can_go_left = true;
        }
        if (!physics.inWall(self.phys, right_pos)) {
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

fn monsterAttack(gs: *game.Session, gc: *c.GameController, self: SystemData, attack_type: enum { shoot, drop_web }) void {
    if (gc.freeze_monsters_timer > 0) {
        return;
    }
    if (self.monster.next_attack_timer > 0) {
        self.monster.next_attack_timer -= 1;
        return;
    }
    switch (attack_type) {
        .shoot => {
            if (self.voice_laser) |voice_laser| {
                voice_laser.params = .{
                    .freq_mul = 0.9 + 0.2 * gs.prng.random.float(f32),
                    .carrier_mul = 4.0,
                    .modulator_mul = 0.125,
                    .modulator_rad = 1.0,
                };
            }
            // spawn the bullet one quarter of a grid cell in front of the monster
            const pos = self.transform.pos;
            const dir_vec = math.getNormal(self.phys.facing);
            const ofs = math.vec2Scale(dir_vec, levels.subpixels_per_tile / 4);
            const bullet_pos = math.vec2Add(pos, ofs);
            _ = p.Bullet.spawn(gs, .{
                .inflictor_player_controller_id = null,
                .owner_id = self.id,
                .pos = bullet_pos,
                .facing = self.phys.facing,
                .bullet_type = .monster_bullet,
                .cluster_size = 1,
                .friendly_fire = false, // this value is irrelevant for monster bullets
            }) catch undefined;
        },
        .drop_web => {
            _ = p.Web.spawn(gs, .{
                .pos = self.transform.pos,
            }) catch undefined;
        },
    }
    self.monster.next_attack_timer = constants.duration60(gs.prng.random.intRangeLessThan(u31, 75, 400));
}

// this function needs more args if this is going to be any good
fn getChaseTarget(gs: *game.Session, self_pos: math.Vec2) ?math.Vec2 {
    // choose the nearest player
    var nearest: ?math.Vec2 = null;
    var nearest_dist: u32 = 0;
    var it = gs.ecs.iter(struct {
        player: *const c.Player,
        transform: *const c.Transform,
    });
    while (it.next()) |entry| {
        const dist = math.manhattanDistance(entry.transform.pos, self_pos);
        if (nearest == null or dist < nearest_dist) {
            nearest = entry.transform.pos;
            nearest_dist = dist;
        }
    }
    return nearest;
}

fn chooseTurn(
    gs: *game.Session,
    personality: c.Monster.Personality,
    pos: math.Vec2,
    facing: math.Direction,
    can_go_forward: bool,
    can_go_left: bool,
    can_go_right: bool,
) ?math.Direction {
    const left = math.rotateCCW(facing);
    const right = math.rotateCW(facing);

    var choices = util.DirectionChoices.init();

    if (personality == .chase) {
        if (getChaseTarget(gs, pos)) |target_pos| {
            // for each potential direction that is unobstructed, come up with a score based on
            // the distance between a point one tile ahead of self in that direction, and the
            // target's position.
            if (can_go_forward) {
                const forward_normal = math.getNormal(facing);
                const forward_point = math.vec2Add(pos, math.vec2Scale(forward_normal, levels.subpixels_per_tile));
                choices.add(facing, math.manhattanDistance(forward_point, target_pos));
            }
            if (can_go_left) {
                const left_normal = math.getNormal(left);
                const left_point = math.vec2Add(pos, math.vec2Scale(left_normal, levels.subpixels_per_tile));
                choices.add(left, math.manhattanDistance(left_point, target_pos));
            }
            if (can_go_right) {
                const right_normal = math.getNormal(right);
                const right_point = math.vec2Add(pos, math.vec2Scale(right_normal, levels.subpixels_per_tile));
                choices.add(right, math.manhattanDistance(right_point, target_pos));
            }
            // choose the direction with the lowest score (shortest distance to the target)
            if (choices.chooseLowest()) |best_direction| {
                if (best_direction != facing) {
                    return best_direction;
                }
            }
            return null;
        }
    }

    // wandering - pick a direction at random. 50% forward, 25% left, 25% right
    if (can_go_forward) choices.add(facing, 2);
    if (can_go_left) choices.add(left, 1);
    if (can_go_right) choices.add(right, 1);

    return choices.chooseRandom(&gs.prng.random);
}

// return the direction a bullet would be fired, or null if not in the line of fire
fn isInLineOfFire(gs: *game.Session, self: SystemData) ?math.Direction {
    const self_absbox = math.moveBox(self.phys.entity_bbox, self.transform.pos);

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
