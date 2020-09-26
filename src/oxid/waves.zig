const std = @import("std");
const game = @import("game.zig");
const c = @import("components.zig");

pub const Wave = struct {
    spiders: u32,
    knights: u32,
    fastbugs: u32,
    squids: u32,
    juggernauts: u32,
    speed: u31,
    message: ?[]const u8,
};

const WaveChoice = struct {
    weight: u32,
    spider_basecount: u31,
    knight_basecount: u31,
    fastbug_basecount: u31,
    squid_basecount: u31,
};

pub fn createWave(gs: *game.Session, gc: *c.GameController) Wave {
    const wavenum = gc.wave_number;

    var spiders: u31 = 0;
    var knights: u31 = 0;
    var fastbugs: u31 = 0;
    var squids: u31 = 0;

    const squid_intro: u31 = 4;
    const fastbug_intro: u31 = 6;

    if (wavenum == 1) {
        spiders = 6;
    } else if (wavenum == squid_intro) {
        spiders = 6;
        squids = 2;
    } else if (wavenum == fastbug_intro) {
        fastbugs = 6;
    } else if (wavenum == 9) {
        knights = 6;
    } else if (wavenum == 11) {
        spiders = 8;
        // first dreadnaut
    } else {
        const choices = [_]WaveChoice{
            .{
                // all regular spiders
                .weight = if (wavenum < 20) 10 else 0,
                .spider_basecount = 8,
                .knight_basecount = 0,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            .{
                // all red spiders
                .weight = 10,
                .spider_basecount = 0,
                .knight_basecount = 6,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            .{
                // all fastbugs
                .weight = if (wavenum > fastbug_intro) 10 else 0,
                .spider_basecount = 0,
                .knight_basecount = 0,
                .fastbug_basecount = 5,
                .squid_basecount = 0,
            },
            .{
                // regular spiders and a few red spiders
                .weight = 10,
                .spider_basecount = 6,
                .knight_basecount = 2,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            .{
                // (almost) equal amount of regular spiders and red spiders
                .weight = 10,
                .spider_basecount = 5,
                .knight_basecount = 4,
                .fastbug_basecount = 0,
                .squid_basecount = 0,
            },
            .{
                // spiders, red spiders and squids
                .weight = if (wavenum > squid_intro) 10 else 0,
                .spider_basecount = 4,
                .knight_basecount = 2,
                .fastbug_basecount = 0,
                .squid_basecount = 2,
            },
            .{
                // red spiders and squids
                .weight = if (wavenum > squid_intro) 10 else 0,
                .spider_basecount = 0,
                .knight_basecount = 5,
                .fastbug_basecount = 0,
                .squid_basecount = 2,
            },
            .{
                // regular spiders, fastbugs, and squids
                .weight = if (wavenum > fastbug_intro) 10 else 0,
                .spider_basecount = 4,
                .knight_basecount = 0,
                .fastbug_basecount = 2,
                .squid_basecount = 2,
            },
            .{
                // everything
                .weight = if (wavenum > 20) 10 else 0,
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
            const r = gs.getRand().intRangeLessThan(u32, 0, total_weight);
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

    return .{
        .spiders = spiders,
        .knights = knights,
        .fastbugs = fastbugs,
        .squids = squids,
        .juggernauts = switch (wavenum) {
            11, 20, 28 => 1,
            else => 0,
        },
        .speed = switch (wavenum) {
            1...9 => 0,
            10...14 => 1,
            else => 2,
        },
        .message = switch (wavenum) {
            1 => "GET READY!",
            4 => "TANK SQUIDS",
            9 => "FIRE BUGS",
            11 => "DREADNAUT!",
            else => null,
        },
    };
}

fn scaleMonsterCount(prng: *std.rand.Random, basenum: u31, wavenum: u32) u31 {
    const factor: f32 = 0.05;
    const f = @intToFloat(f32, basenum) * ((@intToFloat(f32, wavenum) - 1.0) * factor + 1.0);

    const whole = std.math.floor(f);
    const frac = f - whole;

    const add: u31 = if (prng.float(f32) < frac) 1 else 0;

    return @floatToInt(u31, whole) + add;
}
