const std = @import("std");
const pdraw = @import("pdraw");
const math = @import("../common/math.zig");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const vwin_w = @import("../oxid.zig").virtual_window_width;
const vwin_h = @import("../oxid.zig").virtual_window_height;
const hud_height = @import("../oxid.zig").hud_height;
const GameState = @import("../oxid.zig").GameState;
const Constants = @import("constants.zig");
const GameSession = @import("game.zig").GameSession;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const levels = @import("levels.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
const perf = @import("perf.zig");
const util = @import("util.zig");

const primary_font_color_index = 15; // near-white
const heart_font_color_index = 6; // red
const skull_font_color_index = 10; // light grey

pub fn drawGame(g: *GameState) void {
    const mc = g.session.findFirst(c.MainController) orelse return;

    if (mc.game_running_state) |grs| {
        const max_drawables = comptime GameSession.getCapacity(c.EventDraw);
        var sort_buffer: [max_drawables]*const c.EventDraw = undefined;
        const sorted_drawables = getSortedDrawables(g, sort_buffer[0..]);

        pdraw.begin(&g.draw_state, g.tileset.texture.handle, null, 1.0, false);
        drawMap(g);
        drawEntities(g, sorted_drawables);
        drawMapForeground(g);
        pdraw.end(&g.draw_state);

        drawBoxes(g);
        drawHud(g, true);
    } else {
        pdraw.begin(&g.draw_state, g.tileset.texture.handle, null, 1.0, false);
        drawMap(g);
        pdraw.end(&g.draw_state);

        drawHud(g, false);
    }

    if (mc.menu_stack_len > 0) {
        switch (mc.menu_stack_array[mc.menu_stack_len - 1]) {
            .MainMenu => |menu_state| { drawMenu(g, menu_state); },
            .InGameMenu => |menu_state| { drawMenu(g, menu_state); },
            .OptionsMenu => |menu_state| { drawMenu(g, menu_state); },
        }
    }
}

///////////////////////////////////////

fn getSortedDrawables(g: *GameState, sort_buffer: []*const c.EventDraw) []*const c.EventDraw {
    perf.begin(&perf.timers.DrawSort);
    defer perf.end(&perf.timers.DrawSort, g.perf_spam);

    var num_drawables: usize = 0;
    var it = g.session.iter(c.EventDraw); while (it.next()) |object| {
        if (object.is_active) {
            sort_buffer[num_drawables] = &object.data;
            num_drawables += 1;
        }
    }
    var sorted_drawables = sort_buffer[0..num_drawables];
    std.sort.sort(*const c.EventDraw, sorted_drawables, util.lessThanField(*const c.EventDraw, "z_index"));
    return sorted_drawables;
}

fn drawMapTile(g: *GameState, x: u31, y: u31) void {
    const gridpos = math.Vec2.init(x, y);
    if (switch (levels.level1.getGridValue(gridpos).?) {
        0x00 => Graphic.Floor,
        0x80 => Graphic.Wall,
        0x81 => Graphic.Wall2,
        0x82 => Graphic.Pit,
        0x83 => Graphic.EvilWallTL,
        0x84 => Graphic.EvilWallTR,
        0x85 => Graphic.EvilWallBL,
        0x86 => Graphic.EvilWallBR,
        else => null,
    }) |graphic| {
        const pos = math.Vec2.scale(gridpos, levels.subpixels_per_tile);
        const dx = @divFloor(pos.x, levels.subpixels_per_pixel);
        const dy = @divFloor(pos.y, levels.subpixels_per_pixel) + hud_height;
        const dw = levels.pixels_per_tile;
        const dh = levels.pixels_per_tile;
        pdraw.tile(
            &g.draw_state,
            g.tileset,
            getGraphicTile(graphic),
            dx, dy, dw, dh,
            .Identity,
        );
    }
}

fn drawMap(g: *GameState) void {
    perf.begin(&perf.timers.DrawMap);
    defer perf.end(&perf.timers.DrawMap, g.perf_spam);

    var y: u31 = 0; while (y < levels.height) : (y += 1) {
        var x: u31 = 0; while (x < levels.width) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

// make the central 2x2 map tiles a foreground layer, so that the player spawn
// anim makes him arise from behind it. (this should probably be implemented as
// a regular entity later.)
fn drawMapForeground(g: *GameState) void {
    perf.begin(&perf.timers.DrawMapForeground);
    defer perf.end(&perf.timers.DrawMapForeground, g.perf_spam);

    var y: u31 = 6; while (y < 8) : (y += 1) {
        var x: u31 = 9; while (x < 11) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

fn drawEntities(g: *GameState, sorted_drawables: []*const c.EventDraw) void {
    perf.begin(&perf.timers.DrawEntities);
    defer perf.end(&perf.timers.DrawEntities, g.perf_spam);

    for (sorted_drawables) |drawable| {
        const x = @divFloor(drawable.pos.x, levels.subpixels_per_pixel);
        const y = @divFloor(drawable.pos.y, levels.subpixels_per_pixel) + hud_height;
        const w = levels.pixels_per_tile;
        const h = levels.pixels_per_tile;
        pdraw.tile(
            &g.draw_state,
            g.tileset,
            getGraphicTile(drawable.graphic),
            x, y, w, h,
            drawable.transform,
        );
    }
}

fn drawBoxes(g: *GameState) void {
    var it = g.session.iter(c.EventDrawBox); while (it.next()) |object| {
        if (object.is_active) {
            const abs_bbox = object.data.box;
            const x0 = @divFloor(abs_bbox.mins.x, levels.subpixels_per_pixel);
            const y0 = @divFloor(abs_bbox.mins.y, levels.subpixels_per_pixel) + hud_height;
            const x1 = @divFloor(abs_bbox.maxs.x + 1, levels.subpixels_per_pixel);
            const y1 = @divFloor(abs_bbox.maxs.y + 1, levels.subpixels_per_pixel) + hud_height;
            const w = x1 - x0;
            const h = y1 - y0;
            pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, object.data.color, 1.0, true);
            pdraw.tile(
                &g.draw_state,
                g.draw_state.blank_tileset,
                draw.Tile { .tx = 0, .ty = 0 },
                x0, y0, w, h,
                .Identity,
            );
            pdraw.end(&g.draw_state);
        }
    }
}

fn getColor(g: *GameState, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return draw.Color {
        .r = g.palette[index * 3 + 0],
        .g = g.palette[index * 3 + 1],
        .b = g.palette[index * 3 + 2],
    };
}

fn drawHud(g: *GameState, game_active: bool) void {
    perf.begin(&perf.timers.DrawHud);
    defer perf.end(&perf.timers.DrawHud, g.perf_spam);

    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);

    const mc = g.session.findFirst(c.MainController).?;
    const gc_maybe = g.session.findFirst(c.GameController);
    const pc_maybe = g.session.findFirst(c.PlayerController);

    pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        &g.draw_state,
        g.draw_state.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        0, 0, @intToFloat(f32, vwin_w), @intToFloat(f32, hud_height),
        .Identity,
    );
    pdraw.end(&g.draw_state);

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);

    if (gc_maybe) |gc| {
        if (pc_maybe) |pc| {
            const maybe_player_creature =
                if (pc.player_id) |player_id|
                    g.session.find(player_id, c.Creature)
                else
                    null;

            _ = dest.stream.print("Wave:{}", gc.wave_number) catch unreachable; // FIXME
            fontDrawString(&g.draw_state, &g.font, 0, 0, dest.getWritten());
            dest.reset();
            fontDrawString(&g.draw_state, &g.font, 8*8, 0, "Lives:");

            pdraw.end(&g.draw_state);
            const heart_font_color = getColor(g, heart_font_color_index);
            pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, heart_font_color, 1.0, false);
            var i: u31 = 0; while (i < pc.lives) : (i += 1) {
                fontDrawString(&g.draw_state, &g.font, (14+i)*8, 0, "\x1E"); // heart
            }
            pdraw.end(&g.draw_state);

            if (pc.lives == 0) {
                const skull_font_color = getColor(g, skull_font_color_index);
                pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, skull_font_color, 1.0, false);
                fontDrawString(&g.draw_state, &g.font, 14*8, 0, "\x1F"); // skull
                pdraw.end(&g.draw_state);
            }

            pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);

            if (maybe_player_creature) |player_creature| {
                if (player_creature.god_mode) {
                    fontDrawString(&g.draw_state, &g.font, 8*8, 8, "god mode");
                }
            }
            _ = dest.stream.print("Score:{}", pc.score) catch unreachable; // FIXME
            fontDrawString(&g.draw_state, &g.font, 19*8, 0, dest.getWritten());
            dest.reset();
        }

        if (gc.wave_message) |message| {
            if (gc.wave_message_timer > 0) {
                const x = 320 / 2 - message.len * 8 / 2;
                fontDrawString(&g.draw_state, &g.font, @intCast(i32, x), 28*8, message);
            }
        }
    }

    _ = dest.stream.print("High:{}", mc.high_score) catch unreachable; // FIXME
    fontDrawString(&g.draw_state, &g.font, 30*8, 0, dest.getWritten());
    dest.reset();

    pdraw.end(&g.draw_state);

    if (if (gc_maybe) |gc| gc.game_over else false) {
        const y = 8*4;

        if (mc.new_high_score) {
            drawTextBox(g, .Centered, DrawCoord{ .Exact = y }, "GAME OVER\n\nNew high score!");
        } else {
            drawTextBox(g, .Centered, DrawCoord{ .Exact = y }, "GAME OVER");
        }
    }
}

fn drawExitDialog(g: *GameState) void {
    drawTextBox(g, .Centered, .Centered, "Leave game? [Y/N]");
}

fn drawMenu(g: *GameState, menu_state: var) void {
    const T = @typeOf(menu_state);

    var options: [@typeInfo(T).Enum.fields.len]menus.MenuOption = undefined;
    for (options) |*option, i| {
        const i_casted = @intCast(@TagType(T), i);
        const cursor_pos = @intToEnum(T, i_casted);
        option.* = T.getOption(cursor_pos);
    }

    const box_w: u31 = 8 + 8 + 8 * blk: {
        var longest: usize = T.title.len;
        for (options) |option| {
            longest = std.math.max(longest, 4 + option.label.len);
        }
        break :blk @intCast(u31, longest);
    };
    const box_h: u31 = 8 + 8 + 16 + @intCast(u31, options.len) * 10;
    const box_x: i32 = vwin_w / 2 - box_w / 2;
    const box_y: i32 = vwin_h / 2 - box_h / 2;

    pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        &g.draw_state,
        g.draw_state.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        box_x, box_y, box_w, box_h,
        .Identity,
    );
    pdraw.end(&g.draw_state);

    var sx: i32 = box_x + 8;
    var sy: i32 = box_y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, T.title);
    sy += 16;
    for (options) |option, i| {
        if (@enumToInt(menu_state) == i) {
            fontDrawString(&g.draw_state, &g.font, sx, sy, ">");
        }
        fontDrawString(&g.draw_state, &g.font, sx + 16, sy, option.label);
        sy += 10;
    }
    pdraw.end(&g.draw_state);
}

const DrawCoord = union(enum) {
    Centered,
    Exact: i32,
};

fn drawTextBox(g: *GameState, dx: DrawCoord, dy: DrawCoord, text: []const u8) void {
    var tw: u31 = 0;
    var th: u31 = 1;

    {
        var tx: u31 = 0;
        for (text) |ch| {
            if (ch == '\n') {
                tx = 0;
                th += 1;
            } else {
                tx += 1;
                if (tx > tw) {
                    tw = tx;
                }
            }
        }
    }

    const w = 8 * (tw + 2);
    const h = 8 * (th + 2);

    const x = switch (dx) {
        .Centered => i32(vwin_w / 2 - w / 2),
        .Exact => |x| x,
    };
    const y = switch (dy) {
        .Centered => i32(vwin_h / 2 - h / 2),
        .Exact => |y| y,
    };

    pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        &g.draw_state,
        g.draw_state.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        x, y, w, h,
        .Identity,
    );
    pdraw.end(&g.draw_state);

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    {
        var start: usize = 0;
        var sy = y + 8;
        var i: usize = 0; while (i <= text.len) : (i += 1) {
            if (i == text.len or text[i] == '\n') {
                const slice = text[start..i];
                const sw = 8 * @intCast(u31, slice.len);
                const sx = x + i32(w / 2 - sw / 2);
                fontDrawString(&g.draw_state, &g.font, sx, sy, slice);
                sy += 8;
                start = i + 1;
            }
        }
    }
    pdraw.end(&g.draw_state);
}
