const builtin = @import("builtin");
const std = @import("std");
const Constants = @import("constants.zig");
const config = @import("config.zig");
const input = @import("input.zig");
const Key = @import("../common/key.zig").Key;
const key_names = @import("../common/key.zig").key_names;

pub const TextAlignment = enum {
    Left,
    Center,
};

pub const OptionSliderResult = enum {
    Left,
    Right,
};

pub const MenuContext = struct {
    sound_enabled: bool,
    fullscreen: bool,
    cfg: config.Config,
    high_scores: [Constants.num_high_scores]u32,
    new_high_score: bool,
    game_over: bool,
    anim_time: u32,
};

pub const Effect = union(enum) {
    NoOp,
    Push: Menu,
    Pop,
    StartNewGame,
    EndGame,
    ToggleSound,
    SetVolume: u32,
    ToggleFullscreen,
    BindGameCommand: BindGameCommand,
    ResetAnimTime,
    Quit,
};

pub const BindGameCommand = struct {
    command: input.GameCommand,
    key: ?Key,
};

pub const Sound = enum {
    Blip,
    Ding,
    Backoff,
};

pub const Result = struct {
    effect: Effect,
    sound: ?Sound,
};

pub const Menu = union(enum) {
    MainMenu: MainMenu,
    InGameMenu: InGameMenu,
    GameOverMenu: GameOverMenu,
    ReallyEndGameMenu: ReallyEndGameMenu,
    OptionsMenu: OptionsMenu,
    KeyBindingsMenu: KeyBindingsMenu,
    HighScoresMenu: HighScoresMenu,

    pub fn dispatch(self: *Menu, comptime Params: type, params: Params, comptime func: var) ?Result {
        return switch (self.*) {
            .MainMenu          => |*menu_state| func(MainMenu         , menu_state, params),
            .InGameMenu        => |*menu_state| func(InGameMenu       , menu_state, params),
            .GameOverMenu      => |*menu_state| func(GameOverMenu     , menu_state, params),
            .ReallyEndGameMenu => |*menu_state| func(ReallyEndGameMenu, menu_state, params),
            .OptionsMenu       => |*menu_state| func(OptionsMenu      , menu_state, params),
            .KeyBindingsMenu   => |*menu_state| func(KeyBindingsMenu  , menu_state, params),
            .HighScoresMenu    => |*menu_state| func(HighScoresMenu   , menu_state, params),
        };
    }
};

pub const MenuStack = struct {
    const max_size = 3;

    array: [max_size]Menu,
    len: usize,

    pub fn push(self: *MenuStack, new_menu: Menu) void {
        if (self.len == max_size) {
            return;
        }
        self.array[self.len] = new_menu;
        self.len += 1;
    }

    pub fn pop(self: *MenuStack) void {
        if (self.len == 0) {
            return;
        }
        self.len -= 1;
    }

    pub fn clear(self: *MenuStack) void {
        self.len = 0;
    }
};

pub const MainMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "OXID");
    
        if (ctx.option("New game")) {
            ctx.setEffect(.StartNewGame);
            ctx.setSound(.Ding);
        }
        if (ctx.option("Options")) {
            ctx.setEffect(Effect { .Push = Menu { .OptionsMenu = OptionsMenu.init() } });
            ctx.setSound(.Ding);
        }
        if (ctx.option("High scores")) {
            ctx.setEffect(Effect { .Push = Menu { .HighScoresMenu = HighScoresMenu.init() } });
            ctx.setSound(.Ding);
        }
        // quit button is removed in web build
        if (builtin.arch != .wasm32) {
            if (ctx.option("Quit")) {
                ctx.setEffect(.Quit);
            }
        }
    }
};

pub const InGameMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "GAME PAUSED");
    
        if (ctx.option("Continue game")) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
        if (ctx.option("Options")) {
            ctx.setEffect(Effect { .Push = Menu { .OptionsMenu = OptionsMenu.init() } });
            ctx.setSound(.Ding);
        }
        if (ctx.option("End game")) {
            ctx.setEffect(Effect { .Push = Menu { .ReallyEndGameMenu = ReallyEndGameMenu.init() } });
            ctx.setSound(.Ding);
        }
    }
};

pub const GameOverMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (ctx.command) |command| {
            if (command == .Escape) {
                ctx.setEffect(Effect { .Push = Menu { .MainMenu = MainMenu.init() } });
                ctx.setSound(.Backoff);
                return;
            }
        }

        ctx.setPositionTop();
        ctx.title(.Center, "GAME OVER");
        if (ctx.menu_context.new_high_score) {
            ctx.vspacer();
            ctx.title(.Center, "New high score!");
        }
    }
};

pub const ReallyEndGameMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (ctx.command) |command| {
            switch (command) {
                .Yes => {
                    ctx.setEffect(.EndGame);
                    ctx.setSound(.Ding);
                    return;
                },
                .No,
                .Escape => {
                    ctx.setEffect(.Pop);
                    ctx.setSound(.Backoff);
                    return;
                },
                else => {},
            }
        }

        ctx.title(.Center, "Really end game? [Y/N]");
    }
};

pub const OptionsMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }
    
    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "OPTIONS");
    
        if (builtin.arch == .wasm32) {
            if (ctx.option("Sound: {}", if (ctx.menu_context.sound_enabled) "ON" else "OFF")) {
                ctx.setEffect(.ToggleSound);
            }
        }
        const volume = ctx.menu_context.cfg.volume;
        if (ctx.optionSlider("Volume: {}%", volume)) |direction| {
            switch (direction) {
                .Left => {
                    ctx.setEffect(Effect { .SetVolume = if (volume > 10) volume - 10 else 0 });
                    ctx.setSound(.Ding);
                },
                .Right => {
                    ctx.setEffect(Effect { .SetVolume = if (volume < 90) volume + 10 else 100 });
                    ctx.setSound(.Ding);
                },
            }
        }
        if (ctx.option("Fullscreen: {}", if (ctx.menu_context.fullscreen) "ON" else "OFF")) {
            ctx.setEffect(.ToggleFullscreen);
        }
        if (ctx.option("Key bindings")) {
            ctx.setEffect(Effect { .Push = Menu { .KeyBindingsMenu = KeyBindingsMenu.init() } });
            ctx.setSound(.Ding);
        }
        if (ctx.option("Back")) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }
};

pub const KeyBindingsMenu = struct {
    cursor_pos: usize,

    // there is, i think, a compiler bug preventing me from using ?input.GameCommand.
    // the value keeps coming back as 0 (first enum value). it reminds me of this issue:
    // https://github.com/ziglang/zig/issues/3081
    // but it's not the same. that issue has been fixed but this still doesn't work.
    rebinding: bool,
    rebinding_command: input.GameCommand,
    //rebinding: ?input.GameCommand,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
            .rebinding = false,
            .rebinding_command = undefined,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            if (self.rebinding) {
                self.rebinding = false;
            } else {
                ctx.setEffect(.Pop);
            }
            ctx.setSound(.Backoff);
            return;
        }

        if (self.rebinding) { const command = self.rebinding_command;
            if (ctx.key) |key| {
                self.rebinding = false;
                ctx.setEffect(Effect {
                    .BindGameCommand = BindGameCommand {
                        .command = command,
                        .key = key,
                    },
                });
                ctx.setSound(.Ding);
                return;
            }
        }

        const commands = [_]input.GameCommand { .Up, .Down, .Left, .Right, .Shoot };

        const longest_command_name = comptime blk: {
            var longest: usize = 0;
            for (commands) |command, i| {
                longest = std.math.max(longest, @tagName(command).len);
            }
            break :blk longest;
        };

        ctx.title(.Left, "KEY BINDINGS");

        inline for (commands) |command, i| {
            const command_name = @tagName(command) ++ ":" ++ " " ** (longest_command_name - @tagName(command).len);
            self.keyBindingOption(Ctx, ctx, command, command_name);
        }

        ctx.vspacer();

        if (ctx.option("Close")) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }

    fn keyBindingOption(self: *@This(), comptime Ctx: type, ctx: *Ctx, command: input.GameCommand, command_name: []const u8) void {
        const key_name =
            //if (if (self.rebinding) |rebinding_command| rebinding_command == command else false) (
            if (self.rebinding and self.rebinding_command == command) (
                switch (ctx.menu_context.anim_time / 16 % 4) {
                    0 => ".  ",
                    1 => ".. ",
                    2 => "...",
                    else => "",
                }
            ) else if (ctx.menu_context.cfg.game_key_bindings[@enumToInt(command)]) |key| (
                key_names[@enumToInt(key)]
            ) else (
                ""
            );

        if (ctx.option("{} {}", command_name, key_name)) {
            self.rebinding = true;
            self.rebinding_command = command;
            ctx.setEffect(.ResetAnimTime);
            ctx.setSound(.Ding);
        }
    }
};

pub const HighScoresMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return @This() {
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "HIGH SCORES");

        for (ctx.menu_context.high_scores) |score, i| {
            ctx.label("{:3}. {}", i + 1, score);
        }

        ctx.vspacer();

        if (ctx.option("Close")) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }
};
