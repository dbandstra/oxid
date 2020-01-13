const std = @import("std");
const gbe = @import("gbe");
const math = @import("../../common/math.zig");
const audio = @import("../audio.zig");
const GameSession = @import("../game.zig").GameSession;
const levels = @import("../levels.zig");
const ConstantTypes = @import("../constant_types.zig");
const Constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const pickSpawnLocations = @import("../functions/pick_spawn_locations.zig").pickSpawnLocations;
const util = @import("../util.zig");
const createWave = @import("../wave.zig").createWave;

const SystemData = struct {
    id: gbe.EntityId,
    gc: *c.GameController,
};

pub const run = gbe.buildSystem(GameSession, SystemData, think);

fn think(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    // if all non-persistent monsters are dead, prepare next wave
    if (self.gc.next_wave_timer == 0 and countNonPersistentMonsters(gs) == 0) {
        self.gc.next_wave_timer = Constants.next_wave_time;
    }
    _ = util.decrementTimer(&self.gc.wave_message_timer);
    if (util.decrementTimer(&self.gc.next_wave_timer)) {
        p.playSynth(gs, "WaveBegin", audio.WaveBeginVoice.NoteParams {
            .unused = false,
        });
        self.gc.wave_number += 1;
        self.gc.wave_message_timer = Constants.duration60(180);
        self.gc.enemy_speed_level = 0;
        self.gc.enemy_speed_timer = Constants.enemy_speed_ticks;
        const wave = createWave(gs, self.gc);
        spawnWave(gs, self.gc.wave_number, &wave);
        self.gc.enemy_speed_level = wave.speed;
        self.gc.monster_count = countNonPersistentMonsters(gs);
        self.gc.wave_message = wave.message;
    }
    if (util.decrementTimer(&self.gc.enemy_speed_timer)) {
        if (self.gc.enemy_speed_level < Constants.max_enemy_speed_level) {
            self.gc.enemy_speed_level += 1;
            p.playSynth(gs, "Accelerate", audio.AccelerateVoice.NoteParams {
                .playback_speed = switch (self.gc.enemy_speed_level) {
                    1 => 1.25,
                    2 => 1.5,
                    3 => 1.75,
                    else => 2.0,
                },
            });
        }
        self.gc.enemy_speed_timer = Constants.enemy_speed_ticks;
    }
    if (util.decrementTimer(&self.gc.next_pickup_timer)) {
        const pickup_type =
            if ((gs.getRand().scalar(u32) & 1) == 0)
                ConstantTypes.PickupType.SpeedUp
            else
                ConstantTypes.PickupType.PowerUp;
        spawnPickup(gs, pickup_type);
        self.gc.next_pickup_timer = Constants.pickup_spawn_time;
    }
    _ = util.decrementTimer(&self.gc.freeze_monsters_timer);

    // spawn extra life pickup when player's score crosses certain thresholds.
    // note: in multiplayer, extra life will only spawn once per score
    // threshold (so two players does not mean 2x the extra life bonuses)
    var it = gs.entityIter(struct {
        pc: *const c.PlayerController,
    });
    while (it.next()) |entry| {
        if (self.gc.extra_lives_spawned < Constants.extra_life_score_thresholds.len) {
            const threshold = Constants.extra_life_score_thresholds[self.gc.extra_lives_spawned];
            if (entry.pc.score >= threshold) {
                spawnPickup(gs, .LifeUp);
                self.gc.extra_lives_spawned += 1;
            }
        }
    }

    return .Remain;
}

fn countNonPersistentMonsters(gs: *GameSession) u32 {
    var count: u32 = 0;
    var it = gs.entityIter(struct {
        monster: *const c.Monster,
    });
    while (it.next()) |entry| {
        if (entry.monster.persistent) continue;
        count += 1;
    }
    return count;
}

fn spawnWave(gs: *GameSession, wave_number: u32, wave: *const ConstantTypes.Wave) void {
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
                    ConstantTypes.MonsterType.Spider
                else if (i < wave.spiders + wave.knights)
                    ConstantTypes.MonsterType.Knight
                else if (i < wave.spiders + wave.knights + wave.fastbugs)
                    ConstantTypes.MonsterType.FastBug
                else if (i < wave.spiders + wave.knights + wave.fastbugs + wave.squids)
                    ConstantTypes.MonsterType.Squid
                else
                    ConstantTypes.MonsterType.Juggernaut,
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
