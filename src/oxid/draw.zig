const build_options = @import("build_options");
const std = @import("std");
const gbe = @import("gbe");
const pdraw = @import("root").pdraw;
const drawing = @import("../common/drawing.zig");
const fonts = @import("../common/fonts.zig");
const oxid = @import("oxid.zig");
const constants = @import("constants.zig");
const game = @import("game.zig");
const graphics = @import("graphics.zig");
const levels = @import("levels.zig");
const config = @import("config.zig");
const c = @import("components.zig");
const perf = @import("perf.zig");
const util = @import("util.zig");

pub fn drawGame(
    ds: *pdraw.State,
    static: *const oxid.GameStatic,
    maybe_gs: ?*game.Session,
    cfg: config.Config,
    high_score: u32,
) void {
    // draw map background
    drawMap(ds, static, false);

    // draw entities
    if (maybe_gs) |gs| {
        const max_drawables = comptime game.ECS.getCapacity(c.EventDraw);
        var sort_buffer: [max_drawables]*const c.EventDraw = undefined;
        const sorted_drawables = getSortedDrawables(gs, &sort_buffer);

        drawEntities(ds, static, sorted_drawables);
    }

    // draw map foreground
    drawMap(ds, static, true);

    // draw debug overlays
    if (maybe_gs) |gs| {
        drawBoxes(ds, gs);
    }

    // draw HUD
    drawHud(ds, static, maybe_gs, high_score);
}

fn getSortedDrawables(
    gs: *game.Session,
    sort_buffer: []*const c.EventDraw,
) []*const c.EventDraw {
    perf.begin(.draw_sort);
    defer perf.end(.draw_sort);

    var num_drawables: usize = 0;
    var it = gs.ecs.componentIter(c.EventDraw);
    while (it.next()) |event| {
        sort_buffer[num_drawables] = event;
        num_drawables += 1;
    }
    var sorted_drawables = sort_buffer[0..num_drawables];
    std.sort.sort(
        *const c.EventDraw,
        sorted_drawables,
        {},
        comptime util.lessThanField(*const c.EventDraw, "z_index"),
    );
    return sorted_drawables;
}

fn drawMap(ds: *pdraw.State, static: *const oxid.GameStatic, foreground: bool) void {
    perf.begin(if (foreground) .draw_map_foreground else .draw_map);
    defer perf.end(if (foreground) .draw_map_foreground else .draw_map);

    var y: u31 = 0;
    while (y < levels.height) : (y += 1) {
        var x: u31 = 0;
        while (x < levels.width) : (x += 1) {
            const map_tile = levels.getMapTile(levels.level1, x, y) orelse continue;
            if (map_tile.foreground != foreground) continue;
            pdraw.tile(
                ds,
                static.tileset,
                graphics.getGraphicTile(map_tile.graphic),
                @divFloor(x * levels.subpixels_per_tile, levels.subpixels_per_pixel),
                @divFloor(y * levels.subpixels_per_tile, levels.subpixels_per_pixel) + oxid.hud_height,
                .identity,
            );
        }
    }
}

fn drawEntities(
    ds: *pdraw.State,
    static: *const oxid.GameStatic,
    sorted_drawables: []*const c.EventDraw,
) void {
    perf.begin(.draw_entities);
    defer perf.end(.draw_entities);

    for (sorted_drawables) |drawable| {
        pdraw.tile(
            ds,
            static.tileset,
            graphics.getGraphicTile(drawable.graphic),
            @divFloor(drawable.pos.x, levels.subpixels_per_pixel),
            @divFloor(drawable.pos.y, levels.subpixels_per_pixel) + oxid.hud_height,
            drawable.transform,
        );
    }
}

fn drawBoxes(ds: *pdraw.State, gs: *game.Session) void {
    var it = gs.ecs.componentIter(c.EventDrawBox);
    while (it.next()) |event| {
        const abs_bbox = event.box;
        const x0 = @divFloor(abs_bbox.mins.x, levels.subpixels_per_pixel);
        const y0 = @divFloor(abs_bbox.mins.y, levels.subpixels_per_pixel) + oxid.hud_height;
        const x1 = @divFloor(abs_bbox.maxs.x + 1, levels.subpixels_per_pixel);
        const y1 = @divFloor(abs_bbox.maxs.y + 1, levels.subpixels_per_pixel) + oxid.hud_height;
        pdraw.setColor(ds, event.color);
        pdraw.rect(ds, x0, y0, x1 - x0, y1 - y0);
    }
    pdraw.setColor(ds, drawing.pure_white);
}

fn drawHud(
    ds: *pdraw.State,
    static: *const oxid.GameStatic,
    maybe_gs: ?*game.Session,
    high_score: u32,
) void {
    perf.begin(.draw_hud);
    defer perf.end(.draw_hud);

    const font = &static.font;

    const black = graphics.getColor(static.palette, .black);
    const salmon = graphics.getColor(static.palette, .salmon);
    const lightgray = graphics.getColor(static.palette, .lightgray);
    const white = graphics.getColor(static.palette, .white);

    const text_label = lightgray;
    const text_value = white;

    var buffer: [40]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    var stream = fbs.outStream();

    pdraw.setColor(ds, black);
    pdraw.fill(ds, 0, 0, oxid.vwin_w, oxid.hud_height);

    const maybe_gc = if (maybe_gs) |gs|
        gs.ecs.componentIter(c.GameController).next()
    else
        null;

    if (maybe_gc) |gc| {
        const gs = maybe_gs.?;

        pdraw.setColor(ds, text_label);
        fonts.drawString(ds, font, 0, 0, "Wave:");

        pdraw.setColor(ds, text_value);
        _ = stream.print("{}", .{gc.wave_number}) catch unreachable; // FIXME
        fonts.drawString(ds, font, fonts.stringWidth(font, "Wave:"), 0, fbs.getWritten());
        fbs.reset();

        // show little colored helmets in the HUD to make it clear which
        // player is which
        pdraw.setColor(ds, white);
        pdraw.tile(
            ds,
            static.tileset,
            graphics.getGraphicTile(.man_icons),
            40,
            0,
            .identity,
        );
        if (gc.player2_controller_id == null) {
            // both helmets are in the same tile. so if it's single player,
            // cover up the green helmet with a black fill.
            pdraw.setColor(ds, black);
            pdraw.fill(ds, 40, 8, 16, 8);
        }

        for ([_]?gbe.EntityId{
            gc.player1_controller_id,
            gc.player2_controller_id,
        }) |maybe_id, player_index| {
            const id = maybe_id orelse continue;
            const pc = gs.ecs.findComponentById(id, c.PlayerController) orelse continue;

            const y = @intCast(i32, player_index) * 8;

            pdraw.setColor(ds, white);
            fonts.drawString(ds, font, 56, y, "x");

            var lives_x = 56 + fonts.stringWidth(font, "x");

            pdraw.setColor(ds, salmon);
            var i: u31 = 0;
            while (i < pc.lives) : (i += 1) {
                fonts.drawString(ds, font, lives_x, y, "\x1E"); // heart
                switch (pc.lives) {
                    1...5 => lives_x += 8,
                    6 => lives_x += 7,
                    7 => lives_x += 6,
                    8 => lives_x += 5,
                    else => lives_x += 4,
                }
            }
            if (pc.lives == 0) {
                pdraw.setColor(ds, lightgray);
                fonts.drawString(ds, font, lives_x, y, "\x1F"); // skull
            }

            var maybe_oxygen: ?u32 = null;
            if (pc.player_id) |player_id| {
                if (gs.ecs.findComponentById(player_id, c.Player)) |player| {
                    maybe_oxygen = player.oxygen;

                    // low oxygen warning
                    const maybe_mask: ?u32 = switch (player.oxygen) {
                        0, 1 => 8,
                        2, 3 => 16,
                        else => null,
                    };
                    if (maybe_mask) |mask| {
                        if (gc.ticker & mask != 0 and player.dying_timer == 0) {
                            _ = stream.print("P{} TANK LOW!", .{player_index + 1}) catch unreachable; // FIXME
                            const message = fbs.getWritten();
                            defer fbs.reset();

                            const message_w = fonts.stringWidth(font, message);
                            const ax = @as(i32, oxid.vwin_w / 2) - @as(i32, message_w / 2);
                            const ay = @as(i32, oxid.vwin_h / 2) - 8 / 2 + 8 * @intCast(i32, player_index);

                            pdraw.setColor(ds, black);
                            fonts.drawString(ds, font, ax + 1, ay + 1, message);
                            pdraw.setColor(ds, white);
                            fonts.drawString(ds, font, ax, ay, message);
                        }
                    }
                }
            }
            //pdraw.setColor(ds, white);
            if (maybe_oxygen) |oxygen| {
                // \x1D is a superscript 2
                pdraw.setColor(ds, text_label);
                fonts.drawString(ds, font, 114, y, "O\x1D:");

                pdraw.setColor(ds, text_value);
                _ = stream.print("{}", .{oxygen}) catch unreachable; // FIXME
                fonts.drawString(ds, font, 114 + fonts.stringWidth(font, "O\x1D:"), y, fbs.getWritten());
                fbs.reset();
            } else {
                fonts.drawString(ds, font, 114, y, "O\x1D:");
            }

            pdraw.setColor(ds, text_label);
            fonts.drawString(ds, font, 168, y, "Score:");

            pdraw.setColor(ds, text_value);
            _ = stream.print("{}", .{pc.score}) catch unreachable; // FIXME
            fonts.drawString(ds, font, 168 + fonts.stringWidth(font, "Score:"), y, fbs.getWritten());
            fbs.reset();
        }

        if (gc.wave_message) |message| {
            if (gc.wave_message_timer > 0) {
                const message_w = fonts.stringWidth(font, message);
                const x = @as(i32, oxid.vwin_w / 2) - @as(i32, message_w / 2);
                const y = 28 * 8;

                pdraw.setColor(ds, black);
                fonts.drawString(ds, font, x + 1, y + 1, message);
                pdraw.setColor(ds, white);
                fonts.drawString(ds, font, x, y, message);
            }
        }
    } else {
        pdraw.setColor(ds, white);
        fonts.drawString(ds, font, 0, 0, "OXID " ++ build_options.version);
    }

    pdraw.setColor(ds, text_label);
    fonts.drawString(ds, font, 252, 0, "High:");

    pdraw.setColor(ds, text_value);
    _ = stream.print("{}", .{high_score}) catch unreachable; // FIXME
    fonts.drawString(ds, font, 252 + fonts.stringWidth(font, "High:"), 0, fbs.getWritten());
    fbs.reset();

    pdraw.setColor(ds, drawing.pure_white);
}
