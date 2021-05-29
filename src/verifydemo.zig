// given the path to a demo file, simulate it and print the player's score

const std = @import("std");
const game = @import("oxid/game.zig");
const record = @import("oxid/record.zig");
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

    const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
        stderr.print("Failed to open '{s}': {}\n", .{ filename, err }) catch {};
        return 1;
    };
    // file is closed by closePlayer

    var player = record.openPlayer2(file) catch |err| {
        stderr.print("Failed to open player: {}\n", .{err}) catch {};
        file.close();
        return 1;
    };
    defer record.closePlayer(&player);

    var gs: game.Session = undefined; // TODO allocate on heap?

    game.init(&gs, player.game_seed, false);

    while (true) : (player.frame_index += 1) {
        // FIXME will this happen if you end a recording before getting a game over?
        // the recorder should explicitly finalize demo files, when you end the game
        // or get a game over.
        if (player.frame_index > 500000) {
            stderr.print("Runaway loop? Stopped after 500,000 frames\n", .{}) catch {};
            return 1;
        }

        const gc = gs.ecs.componentIter(c.GameController).next() orelse {
            stderr.print("GameController is missing on frame {}\n", .{
                player.frame_index,
            }) catch {};
            return 1;
        };

        const frame_context: game.FrameContext = .{
            .spawn_draw_events = false,
            .friendly_fire = true,
        };

        while (player.next_input) |input| {
            if (input.frame_index > player.frame_index)
                break;
            const player_controller_id = switch (input.player_number) {
                0 => gc.player1_controller_id,
                1 => gc.player2_controller_id,
                else => null,
            } orelse continue;
            p.spawnEventGameInput(&gs, .{
                .player_controller_id = player_controller_id,
                .command = input.command,
                .down = input.down,
            });
            record.readNextInput(&player);
        }

        game.frame(&gs, frame_context, false);

        if (gs.ecs.componentIter(c.EventGameOver).next() != null) {
            const pc = gs.ecs.findComponentById(
                gc.player1_controller_id,
                c.PlayerController,
            ) orelse {
                stderr.print("PlayerController missing on frame {}\n", .{
                    player.frame_index,
                }) catch {};
                return 1;
            };

            stdout.print("{}\n", .{pc.score}) catch {};
            return 0;
        }

        game.frameCleanup(&gs);
    }
}
