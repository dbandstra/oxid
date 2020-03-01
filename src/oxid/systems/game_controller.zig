const std = @import("std");
const math = @import("../../common/math.zig");
const audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const levels = @import("../levels.zig");
const ConstantTypes = @import("../constant_types.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const pickSpawnLocations = @import("../functions/pick_spawn_locations.zig")
    .pickSpawnLocations;
const util = @import("../util.zig");
const createWave = @import("../wave.zig").createWave;

pub fn run(gs: *GameSession) void {
    var it = gs.ecs.iter(struct {
        gc: *c.GameController,
    });
    while (it.next()) |self| {
        think(gs, self.gc);
    }
}

fn think(gs: *GameSession, gc: *c.GameController) void {
    // if all non-persistent monsters are dead, prepare next wave
    if (gc.next_wave_timer == 0 and countNonPersistentMonsters(gs) == 0) {
        gc.next_wave_timer = constants.next_wave_time;
    }
    _ = util.decrementTimer(&gc.wave_message_timer);
    if (util.decrementTimer(&gc.next_wave_timer)) {
        p.playSynth(gs, "wave_begin", audio.WaveBeginVoice, audio.WaveBeginVoice.NoteParams {
            .unused = false,
        });
        gc.wave_number += 1;
        gc.wave_message_timer = constants.duration60(180);
        gc.enemy_speed_level = 0;
        gc.enemy_speed_timer = constants.enemy_speed_ticks;
        const wave = createWave(gs, gc);
        spawnWave(gs, gc.wave_number, &wave);
        gc.enemy_speed_level = wave.speed;
        gc.monster_count = countNonPersistentMonsters(gs);
        gc.wave_message = wave.message;
    }
    if (util.decrementTimer(&gc.enemy_speed_timer)) {
        if (gc.enemy_speed_level < constants.max_enemy_speed_level) {
            gc.enemy_speed_level += 1;
            p.playSynth(gs, "accelerate", audio.AccelerateVoice, audio.AccelerateVoice.NoteParams {
                .playback_speed = switch (gc.enemy_speed_level) {
                    1 => 1.25,
                    2 => 1.5,
                    3 => 1.75,
                    else => 2.0,
                },
            });
        }
        gc.enemy_speed_timer = constants.enemy_speed_ticks;
    }
    if (util.decrementTimer(&gc.next_pickup_timer)) {
        const pickup_type: ConstantTypes.PickupType =
            if ((gs.getRand().scalar(u32) & 1) == 0)
                .speed_up
            else
                .power_up;
        spawnPickup(gs, pickup_type);
        gc.next_pickup_timer = constants.pickup_spawn_time;
    }
    _ = util.decrementTimer(&gc.freeze_monsters_timer);

    // spawn extra life pickup when player's score crosses certain thresholds.
    // note: in multiplayer, extra life will only spawn once per score
    // threshold (so two players does not mean 2x the extra life bonuses)
    var it = gs.ecs.iter(struct {
        pc: *const c.PlayerController,
    });
    while (it.next()) |entry| {
        if (gc.extra_lives_spawned < constants.extra_life_score_thresholds.len) {
            const threshold = constants.extra_life_score_thresholds[gc.extra_lives_spawned];
            if (entry.pc.score >= threshold) {
                spawnPickup(gs, .life_up);
                gc.extra_lives_spawned += 1;
            }
        }
    }
}

fn countNonPersistentMonsters(gs: *GameSession) u32 {
    var count: u32 = 0;
    var it = gs.ecs.iter(struct {
        monster: *const c.Monster,
    });
    while (it.next()) |entry| {
        if (entry.monster.persistent) continue;
        count += 1;
    }
    return count;
}

fn spawnWave(
    gs: *GameSession,
    wave_number: u32,
    wave: *const ConstantTypes.Wave,
) void {
    const count = wave.spiders + wave.knights + wave.fastbugs + wave.squids + wave.juggernauts;
    const coins = (wave.spiders + wave.knights) / 3;
    std.debug.assert(count <= 100);
    var spawn_locs_buf: [100]math.Vec2 = undefined;
    var spawn_locs = spawn_locs_buf[0..count];
    pickSpawnLocations(gs, spawn_locs);
    for (spawn_locs) |loc, i| {
        _ = p.Monster.spawn(gs, .{
            .wave_number = wave_number,
            .pos = math.Vec2.scale(loc, levels.subpixels_per_tile),
            .monster_type =
                if (i < wave.spiders)
                    ConstantTypes.MonsterType.spider
                else if (i < wave.spiders + wave.knights)
                    ConstantTypes.MonsterType.knight
                else if (i < wave.spiders + wave.knights + wave.fastbugs)
                    ConstantTypes.MonsterType.fast_bug
                else if (i < wave.spiders + wave.knights + wave.fastbugs + wave.squids)
                    ConstantTypes.MonsterType.squid
                else
                    ConstantTypes.MonsterType.juggernaut,
            // TODO - distribute coins randomly across monster types?
            .has_coin = i < coins,
        }) catch undefined;
    }
}

fn spawnPickup(gs: *GameSession, pickup_type: ConstantTypes.PickupType) void {
    var spawn_locs: [1]math.Vec2 = undefined;
    pickSpawnLocations(gs, spawn_locs[0..]);
    const pos = math.Vec2.scale(spawn_locs[0], levels.subpixels_per_tile);
    _ = p.Pickup.spawn(gs, .{
        .pos = pos,
        .pickup_type = pickup_type,
    }) catch undefined;
}
