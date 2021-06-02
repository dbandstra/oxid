// given the path to a demo file, simulate it and print the player's score

const std = @import("std");
const game = @import("oxid/game.zig");
const demos = @import("oxid/demos.zig");
const c = @import("oxid/components.zig");
const p = @import("oxid/prototypes.zig");

pub fn main() u8 {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    if (std.os.argv.len != 2) {
        stderr.print("usage: {s} DEMOFILE\n", .{std.os.argv[0]}) catch {};
        return 1;
    }

    const filename = std.mem.spanZ(std.os.argv[1]);

    var player = demos.Player.open(filename) catch |err| {
        stderr.print("Failed to open player: {}\n", .{err}) catch {};
        return 1;
    };
    defer player.close();

    var gs: game.Session = undefined; // TODO allocate on heap?

    game.init(&gs, player.game_seed, false);

    game_loop: while (true) {
        // this should be impossible (it's over 2 hours), but if there are
        // bugs we still want a safety check
        if (player.frame_index > 500000) {
            stderr.print("Runaway loop? Stopped after 500,000 frames\n", .{}) catch {};
            return 1;
        }

        const frame_context: game.FrameContext = .{
            .spawn_draw_events = false,
            .friendly_fire = true,
        };

        while (player.getNextEvent()) |event| {
            switch (event) {
                .end_of_demo => {
                    break :game_loop;
                },
                .input => |input| {
                    const gc = gs.ecs.componentIter(c.GameController).next() orelse {
                        stderr.print("GameController is missing on frame {}\n", .{
                            player.frame_index,
                        }) catch {};
                        return 1;
                    };
                    const player_controller_id = switch (input.player_index) {
                        0 => gc.player1_controller_id,
                        1 => gc.player2_controller_id,
                        else => null,
                    } orelse continue;
                    p.spawnEventGameInput(&gs, .{
                        .player_controller_id = player_controller_id,
                        .command = input.command,
                        .down = input.down,
                    });
                },
            }
            player.readNextInput() catch |err| {
                stderr.print("Error reading from demo file: {}\n", .{err}) catch {};
                return 1;
            };
        }

        game.frame(&gs, frame_context, false);

        if (gs.ecs.componentIter(c.EventGameOver).next() != null) {
            // might as well stop now, there's no possibility of points beyond
            // this point
            break;
        }

        game.frameCleanup(&gs);

        player.incrementFrameIndex() catch |err| {
            stderr.print("Error incrementing frame index: {}\n", .{err}) catch {};
            return 1;
        };
    }

    const gc = gs.ecs.componentIter(c.GameController).next() orelse {
        stderr.print("GameController is missing on frame {}\n", .{player.frame_index}) catch {};
        return 1;
    };
    const pc = gs.ecs.findComponentById(gc.player1_controller_id, c.PlayerController) orelse {
        stderr.print("PlayerController missing on frame {}\n", .{player.frame_index}) catch {};
        return 1;
    };
    stdout.print("{}\n", .{pc.score}) catch {};
    return 0;
}
