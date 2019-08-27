const std = @import("std");
const pdraw = @import("pdraw");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const key_names = @import("../common/key.zig").key_names;
const GameState = @import("../oxid.zig").GameState;
const vwin_w = @import("../oxid.zig").virtual_window_width;
const vwin_h = @import("../oxid.zig").virtual_window_height;
const config = @import("config.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
const input = @import("input.zig");

const primary_font_color_index = 15; // near-white

fn getColor(g: *GameState, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return draw.Color {
        .r = g.palette[index * 3 + 0],
        .g = g.palette[index * 3 + 1],
        .b = g.palette[index * 3 + 2],
    };
}

const Box = struct {
    x: i32,
    y: i32,
    w: u31,
    h: u31,
};

fn calcBox(contents_w: usize, contents_h: usize, padding: bool) Box {
    const w = (if (padding) u31(48) else u31(16)) + @intCast(u31, contents_w);
    const h = (if (padding) u31(32) else u31(16)) + @intCast(u31, contents_h);

    return Box {
        .x = vwin_w / 2 - w / 2,
        .y = vwin_h / 2 - h / 2,
        .w = w,
        .h = h,
    };
}

fn drawBlackBox(g: *GameState, box: Box) void {
    pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        &g.draw_state,
        g.draw_state.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        box.x, box.y, box.w, box.h,
        .Identity,
    );
    pdraw.end(&g.draw_state);
}

pub fn drawGameOverOverlay(g: *GameState, new_high_score: bool) void {
    var box = calcBox(15 * 8, if (new_high_score) u31(8+6+8) else u31(8), false);
    box.y = 8 * 4;
    drawBlackBox(g, box);
    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, box.x + 8 + 24, box.y + 8, "GAME OVER");
    if (new_high_score) {
        fontDrawString(&g.draw_state, &g.font, box.x + 8, box.y + 8 + 8 + 6, "New high score!");
    }
    pdraw.end(&g.draw_state);
}

pub fn drawMenu(g: *GameState, cfg: config.Config, mc: *const c.MainController, menu: menus.Menu) void {
    switch (menu) {
        .MainMenu => |menu_state| drawMainMenu(g, mc, menu_state),
        .InGameMenu => |menu_state| drawInGameMenu(g, mc, menu_state),
        .ReallyEndGameMenu => drawReallyEndGameMenu(g),
        .OptionsMenu => |menu_state| drawOptionsMenu(g, mc, menu_state),
        .KeyBindingsMenu => |menu_state| drawKeyBindingsMenu(g, cfg, mc, menu_state),
        .HighScoresMenu => |menu_state| drawHighScoresMenu(g, mc, menu_state),
    }
}

fn drawMainMenu(g: *GameState, mc: *const c.MainController, menu_state: menus.MainMenu) void {
    const title = "OXID";
    const options = [_][]const u8 {
        "New game",
        "Options",
        "High scores",
        "Quit",
    };

    const box = blk: {
        var longest = title.len;
        for (options) |option| {
            longest = std.math.max(longest, option.len);
        }
        break :blk calcBox(longest * 8, options.len * 10, true);
    };

    drawBlackBox(g, box);

    var sx = box.x + 8;
    var sy = box.y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, title);
    sy += 16;
    for (options) |option, i| {
        if (@enumToInt(menu_state.cursor_pos) == i) {
            fontDrawString(&g.draw_state, &g.font, sx, sy, ">");
        }
        fontDrawString(&g.draw_state, &g.font, sx + 16, sy, option);
        sy += 10;
    }
    pdraw.end(&g.draw_state);
}

fn drawInGameMenu(g: *GameState, mc: *const c.MainController, menu_state: menus.InGameMenu) void {
    const title = "GAME PAUSED";
    const options = [_][]const u8 {
        "Continue game",
        "Options",
        "End game",
    };

    const box = blk: {
        var longest = title.len;
        for (options) |option| {
            longest = std.math.max(longest, option.len);
        }
        break :blk calcBox(longest * 8, options.len * 10, true);
    };

    drawBlackBox(g, box);

    var sx = box.x + 8;
    var sy = box.y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, title);
    sy += 16;
    for (options) |option, i| {
        if (@enumToInt(menu_state.cursor_pos) == i) {
            fontDrawString(&g.draw_state, &g.font, sx, sy, ">");
        }
        fontDrawString(&g.draw_state, &g.font, sx + 16, sy, option);
        sy += 10;
    }
    pdraw.end(&g.draw_state);
}

fn drawReallyEndGameMenu(g: *GameState) void {
    const string = "Really end game? [Y/N]";
    const box = calcBox(string.len * 8, 8, false);
    drawBlackBox(g, box);
    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, box.x + 8, box.y + 8, string);
    pdraw.end(&g.draw_state);
}

fn drawOptionsMenu(g: *GameState, mc: *const c.MainController, menu_state: menus.OptionsMenu) void {
    const title = "OPTIONS";
    const options = [_][]const u8 {
        "Volume",
        "Fullscreen",
        "Key bindings",
        "Back",
    };

    const box = blk: {
        var longest = title.len;
        for (options) |option| {
            longest = std.math.max(longest, option.len);
        }
        break :blk calcBox((longest + 3) * 8, options.len * 10, true);
    };

    drawBlackBox(g, box);

    var sx = box.x + 8;
    var sy = box.y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, title);
    sy += 16;
    for (options) |option, i| {
        var x = sx;
        if (@enumToInt(menu_state.cursor_pos) == i) {
            fontDrawString(&g.draw_state, &g.font, x, sy, ">");
        }
        x += 16;
        fontDrawString(&g.draw_state, &g.font, x, sy, option);
        x += 8 * @intCast(i32, option.len);
        switch (@intToEnum(menus.OptionsMenu.Option, @intCast(@TagType(menus.OptionsMenu.Option), i))) {
            .Volume => {
                var buffer: [40]u8 = undefined;
                var dest = std.io.SliceOutStream.init(buffer[0..]);
                _ = dest.stream.print(": {}%", mc.volume) catch unreachable;
                fontDrawString(&g.draw_state, &g.font, x, sy, dest.getWritten());
            },
            .Fullscreen => {
                fontDrawString(&g.draw_state, &g.font, x, sy, if (mc.is_fullscreen) ": ON" else ": OFF");
            },
            else => {},
        }
        sy += 10;
    }
    pdraw.end(&g.draw_state);
}

fn drawKeyBindingsMenu(g: *GameState, cfg: config.Config, mc: *const c.MainController, menu_state: menus.KeyBindingsMenu) void {
    const title = "KEY BINDINGS";
    const options = [_][]const u8 {
        "Up:    ",
        "Down:  ",
        "Left:  ",
        "Right: ",
        "Shoot: ",
        "Close",
    };
    const box = calcBox(15 * 8, options.len * 10 + 6, true);
    drawBlackBox(g, box);

    var sx = box.x + 8;
    var sy = box.y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, title);
    sy += 16;
    for (options) |option, i| {
        var x = sx;
        if (@enumToInt(menu_state.cursor_pos) == i) {
            fontDrawString(&g.draw_state, &g.font, x, sy, ">");
        }
        x += 16;
        fontDrawString(&g.draw_state, &g.font, x, sy, option);
        x += 8 * @intCast(i32, option.len);
        if (menu_state.rebinding and @enumToInt(menu_state.cursor_pos) == i) {
            const str = switch (mc.menu_anim_time / 16 % 4) {
                0 => ".",
                1 => "..",
                2 => "...",
                else => "",
            };
            fontDrawString(&g.draw_state, &g.font, x, sy, str);
        } else {
            switch (@intToEnum(menus.KeyBindingsMenu.Option, @intCast(@TagType(menus.KeyBindingsMenu.Option), i))) {
                .Up => {
                    if (cfg.game_key_bindings[@enumToInt(input.GameCommand.Up)]) |key| {
                        fontDrawString(&g.draw_state, &g.font, x, sy, key_names[@enumToInt(key)]);
                    }
                },
                .Down => {
                    if (cfg.game_key_bindings[@enumToInt(input.GameCommand.Down)]) |key| {
                        fontDrawString(&g.draw_state, &g.font, x, sy, key_names[@enumToInt(key)]);
                    }
                },
                .Left => {
                    if (cfg.game_key_bindings[@enumToInt(input.GameCommand.Left)]) |key| {
                        fontDrawString(&g.draw_state, &g.font, x, sy, key_names[@enumToInt(key)]);
                    }
                },
                .Right => {
                    if (cfg.game_key_bindings[@enumToInt(input.GameCommand.Right)]) |key| {
                        fontDrawString(&g.draw_state, &g.font, x, sy, key_names[@enumToInt(key)]);
                    }
                },
                .Shoot => {
                    if (cfg.game_key_bindings[@enumToInt(input.GameCommand.Shoot)]) |key| {
                        fontDrawString(&g.draw_state, &g.font, x, sy, key_names[@enumToInt(key)]);
                    }
                },
                .Close => {},
            }
        }
        sy += 10;
        if (i == options.len - 2) { // hax
            sy += 6;
        }
    }
    pdraw.end(&g.draw_state);
}

fn drawHighScoresMenu(g: *GameState, mc: *const c.MainController, menu_state: menus.HighScoresMenu) void {
    const title = "HIGH SCORES";
    const options = [_][]const u8{"Close"};
    const box = calcBox(11 * 8, (options.len + mc.high_scores.len) * 10 + 6, true);
    drawBlackBox(g, box);

    var sx = box.x + 8;
    var sy = box.y + 8;

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);
    fontDrawString(&g.draw_state, &g.font, sx + 16, sy, title);
    sy += 16;
    {
        var buffer: [40]u8 = undefined;
        var dest = std.io.SliceOutStream.init(buffer[0..]);
        for (mc.high_scores) |score, i| {
            _ = dest.stream.print(" {}{}. {}",
                if (i < 9) " " else "", // print doesn't have any way to left-pad with spaces
                i + 1,
                score
            ) catch unreachable; // FIXME
            fontDrawString(&g.draw_state, &g.font, sx, sy, dest.getWritten());
            dest.reset();
            sy += 10;
        }
        sy += 6;
    }
    for (options) |option, i| {
        var x = sx;
        if (@enumToInt(menu_state.cursor_pos) == i) {
            fontDrawString(&g.draw_state, &g.font, x, sy, ">");
        }
        x += 16;
        fontDrawString(&g.draw_state, &g.font, x, sy, option);
        x += 8 * @intCast(i32, option.len);
        sy += 10;
    }
    pdraw.end(&g.draw_state);
}
