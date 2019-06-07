const std = @import("std");
const ConstantTypes = @import("constant_types.zig");
const Wave = ConstantTypes.Wave;
const GameSession = @import("game.zig").GameSession;
const c = @import("components.zig");

const WaveChoice = struct {
    weight: u32,
    spider_basecount: u31,
    knight_basecount: u31,
    fastbug_basecount: u31,
    squid_basecount: u31,
};

pub fn createWave(gs: *GameSession, gc: *c.GameController) Wave {
    const wavenum = gc.wave_number;

    var spiders: u31 = 0;
    var knights: u31 = 0;
    var fastbugs: u31 = 0;
    var squids: u31 = 0;

    const SQUID_INTRO = u31(4);
    const FASTBUG_INTRO = u31(6);

    if (wavenum == 1) {
        spiders = 6;
    } else if (wavenum == SQUID_INTRO) {
        spiders = 6;
        squids = 2;
    } else if (wavenum == FASTBUG_INTRO) {
        fastbugs = 6;
    } else if (wavenum == 9) {
        knights = 6;
    } else if (wavenum == 11) {
        spiders = 8;
        // first dreadnaut
    } else {
        const choices = []WaveChoice {
            WaveChoice {
                // all regular spiders
                .weight = if (wavenum < 20) u32(10) else u32(0),
                .spider_basecount = 8,
                .knight_basecount = 0,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            WaveChoice {
                // all red spiders
                .weight = 10,
                .spider_basecount = 0,
                .knight_basecount = 6,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            WaveChoice {
                // all fastbugs
                .weight = if (wavenum > FASTBUG_INTRO) u32(10) else u32(0),
                .spider_basecount = 0,
                .knight_basecount = 0,
                .fastbug_basecount = 5,
                .squid_basecount = 0,
            },
            WaveChoice {
                // regular spiders and a few red spiders
                .weight = 10,
                .spider_basecount = 6,
                .knight_basecount = 2,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            WaveChoice {
                // (almost)   equal amount of regular spiders and red spiders
                .weight = 10,
                .spider_basecount = 5,
                .knight_basecount = 4,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            WaveChoice {
                // spiders, red spiders and squids
                .weight = if (wavenum > SQUID_INTRO) u32(10) else u32(0),
                .spider_basecount = 4,
                .knight_basecount = 2,
                .fastbug_basecount = 0,
                .squid_basecount = 2,
            },
            WaveChoice {
                // red spiders and squids
                .weight = if (wavenum > SQUID_INTRO) u32(10) else u32(0),
                .spider_basecount = 0,
                .knight_basecount = 5,
                .fastbug_basecount = 0,
                .squid_basecount = 2,
            },
            WaveChoice {
                // regular spiders, fastbugs, and squids
                .weight = if (wavenum > FASTBUG_INTRO) u32(10) else u32(0),
                .spider_basecount = 4,
                .knight_basecount = 0,
                .fastbug_basecount = 2,
                .squid_basecount = 2,
            },
            WaveChoice {
                // everything
                .weight = if (wavenum > 20) u32(10) else u32(0),
                .spider_basecount = 2,
                .knight_basecount = 2,
                .fastbug_basecount = 2,
                .squid_basecount = 2,
            },
        };

        const choice = blk: {
            var total_weight: u32 = 0;
            for (choices) |choice| {
                total_weight += choice.weight;
            }
            const r = gs.getRand().range(u32, 0, total_weight);
            var sum: u32 = 0;
            for (choices) |choice| {
                sum += choice.weight;
                if (r < sum) {
                    break :blk choice;
                }
            }
            unreachable;
        };

        spiders = scaleMonsterCount(gs.getRand(), choice.spider_basecount, wavenum);
        knights = scaleMonsterCount(gs.getRand(), choice.knight_basecount, wavenum);
        fastbugs = scaleMonsterCount(gs.getRand(), choice.fastbug_basecount, wavenum);
        squids = scaleMonsterCount(gs.getRand(), choice.squid_basecount, wavenum);
    }

    return Wave {
        .spiders = spiders,
        .knights = knights,
        .fastbugs = fastbugs,
        .squids = squids,
        .juggernauts = switch (wavenum) {
            11, 20, 28 => u32(1),
            else => u32(0),
        },
        .speed = switch (wavenum) {
            1...9 => u31(0),
            10...14 => u31(1),
            else => u31(2),
        },
        .message = switch (wavenum) {
            1 => ([]const u8)("GET READY!"),
            4 => ([]const u8)("TANK SQUIDS"),
            9 => ([]const u8)("FIRE BUGS"),
            11 => ([]const u8)("DREADNAUT!"),
            else => null,
        },
    };
}

fn scaleMonsterCount(prng: *std.rand.Random, basenum: u31, wavenum: u32) u31 {
    const factor: f32 = 0.05;
    const f = @intToFloat(f32, basenum) * ((@intToFloat(f32, wavenum) - 1.0) * factor + 1.0);

    const whole = std.math.floor(f);
    const frac = f - whole;

    const add = if (prng.float(f32) < frac) u31(1) else u31(0);

    return @floatToInt(u31, whole) + add;
}
