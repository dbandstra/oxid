const menus = @import("menus.zig");
const input = @import("input.zig");
const InputSource = @import("../common/key.zig").InputSource;

const MenuInputContext = struct {
    source: ?InputSource,
    command: ?input.MenuCommand,
    menu_context: menus.MenuContext,
    cursor_pos: usize,
    option_index: usize,
    num_options: usize,
    new_cursor_pos: usize,
    effect: ?menus.Effect,
    sound: ?menus.Sound,

    pub fn setPositionTop(self: *@This()) void {}
    pub fn title(self: *@This(), alignment: menus.TextAlignment, s: []const u8) void {}
    pub fn label(self: *@This(), comptime fmt: []const u8, args: var) void {}
    pub fn vspacer(self: *@This()) void {}

    const OptionInnerResult = enum { left, right, enter };
    fn optionInner(self: *@This(), is_slider: bool, comptime fmt: []const u8, args: var) ?OptionInnerResult {
        defer self.option_index += 1;

        if (self.option_index == self.cursor_pos) {
            if (self.command) |command| {
                switch (command) {
                    .enter => {
                        return .enter;
                    },
                    .left => {
                        return .left;
                    },
                    .right => {
                        return .right;
                    },
                    .up => {
                        self.setSound(.blip);
                        self.new_cursor_pos =
                            if (self.cursor_pos > 0)
                            self.cursor_pos - 1
                        else
                            self.num_options - 1;
                    },
                    .down => {
                        self.setSound(.blip);
                        self.new_cursor_pos =
                            if (self.cursor_pos < self.num_options - 1)
                            self.cursor_pos + 1
                        else
                            0;
                    },
                    else => {},
                }
            }
        }

        return null;
    }

    pub fn option(self: *@This(), comptime fmt: []const u8, args: var) bool {
        // for "buttons", only enter key works
        return if (self.optionInner(false, fmt, args)) |result| result == .enter else false;
    }

    pub fn optionToggle(self: *@This(), comptime fmt: []const u8, args: var) bool {
        // for on/off toggles, left, right and enter keys all work
        return self.optionInner(false, fmt, args) != null;
    }

    pub fn optionSlider(self: *@This(), comptime fmt: []const u8, args: var) ?menus.OptionSliderResult {
        return if (self.optionInner(true, fmt, args)) |result| switch (result) {
            .left => menus.OptionSliderResult.left,
            .right => menus.OptionSliderResult.right,
            else => null,
        } else null;
    }

    pub fn setEffect(self: *@This(), effect: menus.Effect) void {
        self.effect = effect;
    }

    pub fn setSound(self: *@This(), sound: menus.Sound) void {
        self.sound = sound;
    }
};

pub const MenuInputParams = struct {
    source: InputSource,
    maybe_command: ?input.MenuCommand,
    menu_context: menus.MenuContext,
};

pub fn menuInput(menu_stack: *menus.MenuStack, params: MenuInputParams) ?menus.Result {
    if (menu_stack.len == 0) {
        return null;
    }
    return menu_stack.array[menu_stack.len - 1].dispatch(MenuInputParams, params, menuInputInner);
}

fn menuInputInner(
    comptime T: type,
    state: *T,
    params: MenuInputParams,
) ?menus.Result {
    var ctx: MenuInputContext = .{
        .source = null,
        .command = null,
        .menu_context = params.menu_context,
        .cursor_pos = state.cursor_pos,
        .option_index = 0,
        .num_options = 0,
        .new_cursor_pos = state.cursor_pos,
        .effect = null,
        .sound = null,
    };

    // analyze (get number of options)
    state.func(MenuInputContext, &ctx);

    const num_options = ctx.option_index;

    // handle input
    ctx = .{
        .source = params.source,
        .command = params.maybe_command,
        .menu_context = params.menu_context,
        .cursor_pos = state.cursor_pos,
        .option_index = 0,
        .num_options = num_options,
        .new_cursor_pos = state.cursor_pos,
        .effect = null,
        .sound = null,
    };

    state.func(MenuInputContext, &ctx);

    state.cursor_pos = ctx.new_cursor_pos;

    if (ctx.effect != null or ctx.sound != null) {
        // FIXME - can't use anonymous struct literal here (for menus.Result)
        // file an issue?
        return menus.Result{
            .effect = ctx.effect orelse .noop,
            .sound = ctx.sound,
        };
    }
    return null;
}
