const builtin = @import("builtin");
const std = @import("std");
const pdraw = @import("pdraw");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const Key = @import("../common/key.zig").Key;
const common = @import("../oxid_common.zig");
const config = @import("config.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
const input = @import("input.zig");

const font_char_width = @import("../common/font.zig").font_char_width;
const font_char_height = @import("../common/font.zig").font_char_height;

const primary_font_color_index = 15; // near-white

fn getColor(static: *const common.GameStatic, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return draw.Color {
        .r = static.palette[index * 3 + 0],
        .g = static.palette[index * 3 + 1],
        .b = static.palette[index * 3 + 2],
    };
}

pub const DrawMenuContext = struct {
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    menu_context: menus.MenuContext,
    cursor_pos: usize,
    position_top: bool,
    box_x: i32,
    box_y: i32,
    box_w: u31,
    box_h: u31,
    w: u31,
    h: u31,
    bottom_margin: u31,
    draw: bool,
    option_index: usize,
    key: ?Key,
    command: ?input.MenuCommand,

    pub fn setPositionTop(self: *@This()) void {
        self.position_top = true;
    }

    fn textHelper(self: *@This(), alignment: menus.TextAlignment, s: []const u8) void {
        const w = blk: {
            const base_w = @intCast(u31, s.len) * font_char_width;
            break :blk switch (alignment) {
                .Left => base_w + 32, // pad both sides
                .Center => base_w,
            };
        };

        self.h += self.bottom_margin;
        if (self.draw) {
            const x = switch (alignment) {
                .Left => self.box_x + 16,
                .Center => self.box_x + i32(self.box_w / 2) - i32(w / 2),
            };
            const font_color = getColor(self.static, primary_font_color_index);
            pdraw.begin(self.ds, self.static.font.tileset.texture.handle, font_color, 1.0, false);
            fontDrawString(self.ds, &self.static.font, x, self.box_y + i32(self.h), s);
            pdraw.end(self.ds);
        }
        self.w = std.math.max(self.w, w);
        self.h += font_char_height;
    }

    pub fn title(self: *@This(), alignment: menus.TextAlignment, s: []const u8) void {
        self.textHelper(alignment, s);
        self.bottom_margin = 2 + 6;
    }

    pub fn label(self: *@This(), comptime fmt: []const u8, args: ...) void {
        var buffer: [80]u8 = undefined;
        var dest = std.io.SliceOutStream.init(buffer[0..]);
        _ = dest.stream.print(fmt, args) catch {};
        const s = dest.getWritten();

        self.textHelper(.Left, s);
        self.bottom_margin = 2;
    }

    pub fn vspacer(self: *@This()) void {
        self.bottom_margin += 6;
    }

    pub fn option(self: *@This(), comptime fmt: []const u8, args: ...) bool {
        var buffer: [80]u8 = undefined;
        var dest = std.io.SliceOutStream.init(buffer[0..]);
        _ = dest.stream.print(fmt, args) catch {};
        const s = dest.getWritten();

        self.h += self.bottom_margin;
        if (self.draw) {
            const font_color = getColor(self.static, primary_font_color_index);
            pdraw.begin(self.ds, self.static.font.tileset.texture.handle, font_color, 1.0, false);
            if (self.cursor_pos == self.option_index) {
                fontDrawString(self.ds, &self.static.font, self.box_x, self.box_y + i32(self.h), ">");
            }
            fontDrawString(self.ds, &self.static.font, self.box_x + 16, self.box_y + i32(self.h), s);
            pdraw.end(self.ds);
        }
        self.option_index += 1;
        self.w = std.math.max(self.w, @intCast(u31, s.len) * font_char_width + 32); // pad both sides
        self.h += font_char_height;
        self.bottom_margin = 2;
        return false;
    }

    pub fn optionToggle(self: *@This(), comptime fmt: []const u8, args: ...) bool {
        return self.option(fmt, args);
    }

    pub fn optionSlider(self: *@This(), comptime fmt: []const u8, args: ...) ?menus.OptionSliderResult {
        _ = self.option(fmt, args);
        return null;
    }

    pub fn setEffect(self: *@This(), effect: menus.Effect) void {}
    pub fn setSound(self: *@This(), sound: menus.Sound) void {}
};

pub const MenuDrawParams = struct {
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    menu_context: menus.MenuContext,
};

pub fn drawMenu(menu_stack: *menus.MenuStack, params: MenuDrawParams) void {
    if (menu_stack.len == 0) {
        return;
    }
    _ = menu_stack.array[menu_stack.len - 1].dispatch(MenuDrawParams, params, drawMenuInner);
}

fn drawMenuInner(comptime T: type, state: *T, params: MenuDrawParams) ?menus.Result {
    // first measure the context (.draw = false)
    var ctx = DrawMenuContext {
        .ds = params.ds,
        .static = params.static,
        .menu_context = params.menu_context,
        .cursor_pos = state.cursor_pos,
        .position_top = false,
        .box_x = 0,
        .box_y = 0,
        .box_w = 0,
        .box_h = 0,
        .w = 0,
        .h = 0,
        .bottom_margin = 0,
        .draw = false,
        .option_index = 0,
        .key = null,
        .command = null,
    };

    state.func(DrawMenuContext, &ctx);

    // draw background box
    const pad_left = 8;
    const pad_right = 8;
    const pad_vert = 8;
    const box_w = pad_left + pad_right + ctx.w;
    const box_h = pad_vert * 2 + ctx.h;
    const box_x = i32(common.virtual_window_width / 2) - i32(box_w / 2);
    const box_y =
        if (!ctx.position_top)
            i32(common.virtual_window_height / 2) - i32(box_h / 2)
        else
            32;

    pdraw.begin(params.ds, params.ds.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        params.ds,
        params.ds.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        box_x, box_y, box_w, box_h,
        .Identity,
    );
    pdraw.end(params.ds);

    // draw menu content
    ctx = DrawMenuContext {
        .ds = params.ds,
        .static = params.static,
        .menu_context = params.menu_context,
        .cursor_pos = state.cursor_pos,
        .position_top = false,
        .box_x = box_x + pad_left,
        .box_y = box_y + pad_vert,
        .box_w = ctx.w,
        .box_h = ctx.h,
        .w = 0,
        .h = 0,
        .bottom_margin = 0,
        .draw = true,
        .option_index = 0,
        .key = null,
        .command = null,
    };

    state.func(DrawMenuContext, &ctx);

    return null;
}
