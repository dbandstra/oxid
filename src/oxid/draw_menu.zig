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
const drawTextBox = @import("draw.zig").drawTextBox;

const primary_font_color_index = 15; // near-white

fn getColor(g: *GameState, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return draw.Color {
        .r = g.palette[index * 3 + 0],
        .g = g.palette[index * 3 + 1],
        .b = g.palette[index * 3 + 2],
    };
}

pub fn drawMenu(g: *GameState, cfg: config.Config, mc: *const c.MainController, menu: menus.Menu) void {
    switch (menu) {
        .MainMenu => |menu_state| { drawMenu2(g, cfg, mc, menu_state); },
        .InGameMenu => |menu_state| { drawMenu2(g, cfg, mc, menu_state); },
        .ReallyEndGameMenu => { drawTextBox(g, .Centered, .Centered, "Really end game? [Y/N]"); },
        .OptionsMenu => |menu_state| { drawMenu2(g, cfg, mc, menu_state); },
        .KeyBindingsMenu => |menu_state| { drawMenu2(g, cfg, mc, menu_state); },
        .HighScoresMenu => |menu_state| { drawMenu2(g, cfg, mc, menu_state); },
    }
}

fn drawMenu2(g: *GameState, cfg: config.Config, mc: *const c.MainController, menu_state: var) void {
    const T = @typeOf(menu_state);

    var options: [@typeInfo(T.Option).Enum.fields.len]menus.MenuOption = undefined;
    for (options) |*option, i| {
        if (@TagType(T.Option) == comptime_int) {
            // https://github.com/ziglang/zig/issues/2997
            const cursor_pos: T.Option = undefined;
            option.* = T.getOption(cursor_pos);
        } else {
            const i_casted = @intCast(@TagType(T.Option), i);
            const cursor_pos = @intToEnum(T.Option, i_casted);
            option.* = T.getOption(cursor_pos);
        }
    }

    const box_w: u31 = 8 + 8 + 32 + 8 * blk: {
        var longest: usize = T.title.len;
        for (options) |option| {
            var w = option.label.len;
            if (option.value != null) { w += 5; }
            longest = std.math.max(longest, w);
        }
        break :blk @intCast(u31, longest);
    };
    const box_h: u31 = 8 + 8 + 16 + @intCast(u31, options.len) * 10 + (
        if (@typeOf(menu_state) == menus.KeyBindingsMenu)
            u31(6)
        else if (@typeOf(menu_state) == menus.HighScoresMenu)
            6 + @intCast(u31, mc.high_scores.len) * 10
        else
            u31(0)
    );
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
    if (@typeOf(menu_state) == menus.HighScoresMenu) { // hax
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
        fontDrawString(&g.draw_state, &g.font, x, sy, option.label);
        x += 8 * @intCast(i32, option.label.len);
        if (option.value) |getter| {
            fontDrawString(&g.draw_state, &g.font, x, sy, if (getter(mc)) ": ON" else ": OFF");
            x += 8 * 5;
        }
        if (@typeOf(menu_state) == menus.KeyBindingsMenu) {
            if (menu_state.rebinding and @enumToInt(menu_state.cursor_pos) == i) {
                // TODO - make it blink or animate?
                fontDrawString(&g.draw_state, &g.font, x, sy, "...");
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
        }
        sy += 10;
        if (@typeOf(menu_state) == menus.KeyBindingsMenu and i == options.len - 2) { // hax
            sy += 6;
        }
    }
    pdraw.end(&g.draw_state);
}
