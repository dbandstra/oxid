const std = @import("std");
const math = @import("../../common/math.zig");
const game = @import("../game.zig");
const levels = @import("../levels.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const pickSpawnLocation = @import("../functions/pick_spawn_locations.zig").pickSpawnLocation;
const pickSpawnLocations = @import("../functions/pick_spawn_locations.zig").pickSpawnLocations;
const waves = @import("../waves.zig");

const SystemData = struct {
    gc: *c.GameController,
    voice_accelerate: *c.VoiceAccelerate,
    voice_wave_begin: *c.VoiceWaveBegin,
};

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(SystemData);
    while (it.next()) |self| {
        think(gs, self);
    }
}

fn think(gs: *game.Session, self: SystemData) void {
    // if all non-persistent monsters are dead, prepare next wave
    if (self.gc.next_wave_timer == 0 and countNonPersistentMonsters(gs) == 0) {
        self.gc.next_wave_timer = constants.next_wave_time;
    }
    if (self.gc.wave_message_timer > 0) {
        self.gc.wave_message_timer -= 1;
    }
    if (self.gc.next_wave_timer > 0) {
        self.gc.next_wave_timer -= 1;
        if (self.gc.next_wave_timer == 0) {
            self.voice_wave_begin.params = .{};
            self.gc.wave_number += 1;
            self.gc.wave_message_timer = constants.duration60(180);
            self.gc.enemy_speed_level = 0;
            self.gc.enemy_speed_timer = constants.enemy_speed_ticks;
            const wave = waves.createWave(gs, self.gc);
            spawnWave(gs, self.gc.wave_number, &wave);
            self.gc.enemy_speed_level = wave.speed;
            self.gc.monster_count = countNonPersistentMonsters(gs);
            self.gc.wave_message = wave.message;
        }
    }
    if (self.gc.enemy_speed_timer > 0) {
        self.gc.enemy_speed_timer -= 1;
        if (self.gc.enemy_speed_timer == 0) {
            if (self.gc.enemy_speed_level < constants.max_enemy_speed_level) {
                self.gc.enemy_speed_level += 1;
                self.voice_accelerate.params = .{
                    .playback_speed = switch (self.gc.enemy_speed_level) {
                        1 => 1.25,
                        2 => 1.5,
                        3 => 1.75,
                        else => 2.0,
                    },
                };
            }
            self.gc.enemy_speed_timer = constants.enemy_speed_ticks;
        }
    }
    if (self.gc.next_pickup_timer > 0) {
        self.gc.next_pickup_timer -= 1;
        if (self.gc.next_pickup_timer == 0) {
            spawnPickup(gs, if (gs.prng.random.boolean()) .speed_up else .power_up);
            self.gc.next_pickup_timer = constants.pickup_spawn_time;
        }
    }
    if (self.gc.freeze_monsters_timer > 0) {
        self.gc.freeze_monsters_timer -= 1;
    }

    // spawn extra life pickup when player's score crosses certain thresholds.
    // note: in multiplayer, extra life will only spawn once per score
    // threshold (so two players does not mean 2x the extra life bonuses)
    var it = gs.ecs.iter(struct {
        pc: *const c.PlayerController,
    });
    while (it.next()) |entry| {
        if (self.gc.extra_lives_spawned < constants.extra_life_score_thresholds.len) {
            const threshold = constants.extra_life_score_thresholds[self.gc.extra_lives_spawned];
            if (entry.pc.score >= threshold) {
                spawnPickup(gs, .life_up);
                self.gc.extra_lives_spawned += 1;
            }
        }
    }
}

fn countNonPersistentMonsters(gs: *game.Session) u32 {
    var count: u32 = 0;
    var it = gs.ecs.componentIter(c.Monster);
    while (it.next()) |monster| {
        if (!constants.getMonsterValues(monster.monster_type).persistent) {
            count += 1;
        }
    }
    return count;
}

fn spawnWave(gs: *game.Session, wave_number: u32, wave: *const waves.Wave) void {
    const count = wave.spiders + wave.knights + wave.fastbugs + wave.squids + wave.juggernauts;
    const coins = (wave.spiders + wave.knights) / 3;
    std.debug.assert(count <= 100);
    var spawn_locs_buf: [100]math.Vec2 = undefined;
    for (pickSpawnLocations(gs, spawn_locs_buf[0..count])) |loc, i| {
        _ = p.spawnMonster(gs, .{
            .wave_number = wave_number,
            .pos = math.vec2Scale(loc, levels.subpixels_per_tile),
            .monster_type = if (i < wave.spiders)
                constants.MonsterType.spider
            else if (i < wave.spiders + wave.knights)
                constants.MonsterType.knight
            else if (i < wave.spiders + wave.knights + wave.fastbugs)
                constants.MonsterType.fast_bug
            else if (i < wave.spiders + wave.knights + wave.fastbugs + wave.squids)
                constants.MonsterType.squid
            else
                constants.MonsterType.juggernaut,
            // TODO - distribute coins randomly across monster types?
            .has_coin = i < coins,
        });
    }
}

fn spawnPickup(gs: *game.Session, pickup_type: constants.PickupType) void {
    const spawn_loc = pickSpawnLocation(gs) orelse return;
    _ = p.spawnPickup(gs, .{
        .pos = math.vec2Scale(spawn_loc, levels.subpixels_per_tile),
        .pickup_type = pickup_type,
    });
}
