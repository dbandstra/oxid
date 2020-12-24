const builtin = @import("builtin");
const std = @import("std");
const pdraw = @import("root").pdraw;
const draw = @import("../common/draw.zig");
const fonts = @import("../common/fonts.zig");
const InputSource = @import("../common/key.zig").InputSource;
const common = @import("../oxid_common.zig");
const config = @import("config.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
const input = @import("input.zig");
const graphics = @import("graphics.zig");

pub const DrawMenuContext = struct {
    ds: *pdraw.State,
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
    source: ?InputSource,
    command: ?input.MenuCommand,

    pub fn setPositionTop(self: *@This()) void {
        self.position_top = true;
    }

    fn textHelper(self: *@This(), alignment: menus.TextAlignment, s: []const u8) void {
        const w = blk: {
            const base_w = fonts.stringWidth(&self.static.font, s);
            break :blk switch (alignment) {
                .left => base_w + 32, // pad both sides
                .center => base_w,
            };
        };

        self.h += self.bottom_margin;
        if (self.draw) {
            const x = switch (alignment) {
                .left => self.box_x + 16,
                .center => self.box_x + @as(i32, self.box_w / 2) - @as(i32, w / 2),
            };
            const font_color = graphics.getColor(self.static.palette, .white);
            pdraw.begin(self.ds, self.static.font.tileset.texture.handle, font_color, 1.0, false);
            fonts.drawString(self.ds, &self.static.font, x, self.box_y + @as(i32, self.h), s);
            pdraw.end(self.ds);
        }
        self.w = std.math.max(self.w, w);
        self.h += self.static.font.char_height;
    }

    pub fn title(self: *@This(), alignment: menus.TextAlignment, s: []const u8) void {
        self.textHelper(alignment, s);
        self.bottom_margin = 2 + 6;
    }

    pub fn label(self: *@This(), comptime fmt: []const u8, args: anytype) void {
        var buffer: [80]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        _ = fbs.outStream().print(fmt, args) catch {};
        const s = fbs.getWritten();

        self.textHelper(.left, s);
        self.bottom_margin = 2;
    }

    pub fn vspacer(self: *@This()) void {
        self.bottom_margin += 6;
    }

    pub fn option(self: *@This(), comptime fmt: []const u8, args: anytype) bool {
        var buffer: [80]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        _ = fbs.outStream().print(fmt, args) catch {};
        const s = fbs.getWritten();

        self.h += self.bottom_margin;
        if (self.draw) {
            const font_color = graphics.getColor(self.static.palette, .white);
            pdraw.begin(self.ds, self.static.font.tileset.texture.handle, font_color, 1.0, false);
            if (self.cursor_pos == self.option_index) {
                fonts.drawString(self.ds, &self.static.font, self.box_x, self.box_y + @as(i32, self.h), ">");
            }
            fonts.drawString(self.ds, &self.static.font, self.box_x + 16, self.box_y + @as(i32, self.h), s);
            pdraw.end(self.ds);
        }
        self.option_index += 1;
        self.w = std.math.max(self.w, fonts.stringWidth(&self.static.font, s) + 32); // pad both sides
        self.h += self.static.font.char_height;
        self.bottom_margin = 2;
        return false;
    }

    pub fn optionToggle(self: *@This(), comptime fmt: []const u8, args: anytype) bool {
        return self.option(fmt, args);
    }

    pub fn optionSlider(self: *@This(), comptime fmt: []const u8, args: anytype) ?menus.OptionSliderResult {
        _ = self.option(fmt, args);
        return null;
    }

    pub fn setEffect(self: *@This(), effect: menus.Effect) void {}
    pub fn setSound(self: *@This(), sound: menus.Sound) void {}
};

pub const MenuDrawParams = struct {
    ds: *pdraw.State,
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
    var ctx: DrawMenuContext = .{
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
        .source = null,
        .command = null,
    };

    state.func(DrawMenuContext, &ctx);

    // draw background box
    const pad_left = 8;
    const pad_right = 8;
    const pad_vert = 8;
    const box_w = pad_left + pad_right + ctx.w;
    const box_h = pad_vert * 2 + ctx.h;
    const box_x = @as(i32, common.vwin_w / 2) - @as(i32, box_w / 2);
    const box_y = if (!ctx.position_top)
        @as(i32, common.vwin_h / 2) - @as(i32, box_h / 2)
    else
        32;

    const black = graphics.getColor(params.static.palette, .black);
    pdraw.begin(params.ds, params.ds.blank_tex.handle, black, 1.0, false);
    pdraw.tile(
        params.ds,
        params.ds.blank_tileset,
        .{ .tx = 0, .ty = 0 },
        box_x,
        box_y,
        box_w,
        box_h,
        .identity,
    );
    pdraw.end(params.ds);

    // draw menu content
    ctx = .{
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
        .source = null,
        .command = null,
    };

    state.func(DrawMenuContext, &ctx);

    return null;
}
