const builtin = @import("builtin");
const std = @import("std");
const Constants = @import("constants.zig");
const config = @import("config.zig");
const input = @import("input.zig");
const Key = @import("../common/key.zig").Key;
const InputSource = @import("../common/key.zig").InputSource;
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
    canvas_scale: u31,
    max_canvas_scale: u31,
    friendly_fire: bool,
};

pub const Effect = union(enum) {
    NoOp,
    Push: Menu,
    Pop,
    StartNewGame: bool,
    EndGame,
    ToggleSound,
    SetVolume: u32,
    SetCanvasScale: u31,
    ToggleFullscreen,
    ToggleFriendlyFire,
    BindGameCommand: BindGameCommand,
    ResetAnimTime,
    Quit,
};

pub const BindGameCommand = struct {
    player_number: u32,
    command: input.GameCommand,
    source: ?InputSource,
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
    GameSettingsMenu: GameSettingsMenu,
    KeyBindingsMenu: KeyBindingsMenu,
    HighScoresMenu: HighScoresMenu,

    pub fn dispatch(self: *Menu, comptime Params: type, params: Params, comptime func: var) ?Result {
        return switch (self.*) {
            .MainMenu          => |*menu_state| func(MainMenu         , menu_state, params),
            .InGameMenu        => |*menu_state| func(InGameMenu       , menu_state, params),
            .GameOverMenu      => |*menu_state| func(GameOverMenu     , menu_state, params),
            .ReallyEndGameMenu => |*menu_state| func(ReallyEndGameMenu, menu_state, params),
            .OptionsMenu       => |*menu_state| func(OptionsMenu      , menu_state, params),
            .GameSettingsMenu  => |*menu_state| func(GameSettingsMenu , menu_state, params),
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
        return .{
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "OXID");

        if (ctx.option("New game", .{})) {
            ctx.setEffect(.{.StartNewGame = false});
            ctx.setSound(.Ding);
        }
        if (ctx.option("Multiplayer", .{})) {
            ctx.setEffect(.{.StartNewGame = true});
            ctx.setSound(.Ding);
        }
        if (ctx.option("Options", .{})) {
            ctx.setEffect(.{.Push = .{.OptionsMenu = OptionsMenu.init()}});
            ctx.setSound(.Ding);
        }
        if (ctx.option("High scores", .{})) {
            ctx.setEffect(.{.Push = .{.HighScoresMenu = HighScoresMenu.init()}});
            ctx.setSound(.Ding);
        }
        // quit button is removed in web build
        if (builtin.arch != .wasm32) {
            if (ctx.option("Quit", .{})) {
                ctx.setEffect(.Quit);
            }
        }
    }
};

pub const InGameMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return .{
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

        if (ctx.option("Continue game", .{})) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
        if (ctx.option("Options", .{})) {
            ctx.setEffect(.{.Push = .{.OptionsMenu = OptionsMenu.init()}});
            ctx.setSound(.Ding);
        }
        if (ctx.option("End game", .{})) {
            ctx.setEffect(.{.Push = .{.ReallyEndGameMenu = ReallyEndGameMenu.init()}});
            ctx.setSound(.Ding);
        }
    }
};

pub const GameOverMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return .{
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (ctx.command) |command| {
            if (command == .Escape) {
                ctx.setEffect(.{.Push = .{.MainMenu = MainMenu.init()}});
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
        return .{
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
        return .{
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
            if (ctx.optionToggle("Sound: {}", [_][]const u8 {
                if (ctx.menu_context.sound_enabled) "ON" else "OFF",
            })) {
                ctx.setEffect(.ToggleSound);
                // don't play sound because the sound init/deinit may not be done in time to pick the new sound up
            }
        }
        const volume = ctx.menu_context.cfg.volume;
        if (ctx.optionSlider("Volume: {}%", .{volume})) |direction| {
            switch (direction) {
                .Left => {
                    if (volume > 0) {
                        ctx.setEffect(.{.SetVolume = if (volume > 10) volume - 10 else 0});
                    }
                },
                .Right => {
                    if (volume < 100) {
                        ctx.setEffect(.{.SetVolume = if (volume < 90) volume + 10 else 100});
                    }
                },
            }
            ctx.setSound(.Ding);
        }
        const canvas_scale = ctx.menu_context.canvas_scale;
        if (ctx.optionSlider("Canvas scale: {}x", .{ctx.menu_context.canvas_scale})) |direction| {
            switch (direction) {
                .Left => {
                    if (canvas_scale > 1) {
                        ctx.setEffect(.{.SetCanvasScale = canvas_scale - 1});
                    }
                },
                .Right => {
                    if (canvas_scale < ctx.menu_context.max_canvas_scale) {
                        ctx.setEffect(.{.SetCanvasScale = canvas_scale + 1});
                    }
                },
            }
            ctx.setSound(.Ding);
        }
        if (ctx.optionToggle("Fullscreen: {}", [_][]const u8 {
            if (ctx.menu_context.fullscreen) "ON" else "OFF",
        })) {
            ctx.setEffect(.ToggleFullscreen);
            // don't play a sound because the fullscreen transition might mess with playback
        }
        if (ctx.option("Game settings", .{})) {
            ctx.setEffect(.{.Push = .{.GameSettingsMenu = GameSettingsMenu.init()}});
            ctx.setSound(.Ding);
        }
        if (ctx.option("Key bindings", .{})) {
            ctx.setEffect(.{.Push = .{.KeyBindingsMenu = KeyBindingsMenu.init()}});
            ctx.setSound(.Ding);
        }
        if (ctx.option("Back", .{})) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }
};

pub const GameSettingsMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return .{
            .cursor_pos = 0,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Backoff);
            return;
        }

        ctx.title(.Left, "GAME SETTINGS");

        if (ctx.optionToggle("Friendly fire: {}", [_][]const u8 {
            if (ctx.menu_context.friendly_fire) "ON" else "OFF",
        })) {
            ctx.setEffect(.ToggleFriendlyFire);
            ctx.setSound(.Ding);
        }
        if (ctx.option("Back", .{})) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }
};

pub const KeyBindingsMenu = struct {
    cursor_pos: usize,
    for_player: u32,
    rebinding: ?input.GameCommand,

    pub fn init() @This() {
        return .{
            .cursor_pos = 0,
            .for_player = 0,
            .rebinding = null,
        };
    }

    pub fn func(self: *@This(), comptime Ctx: type, ctx: *Ctx) void {
        if (if (ctx.command) |command| command == .Escape else false) {
            if (self.rebinding != null) {
                self.rebinding = null;
            } else {
                ctx.setEffect(.Pop);
            }
            ctx.setSound(.Backoff);
            return;
        }

        if (self.rebinding) |command| {
            if (ctx.source) |source| {
                ctx.setEffect(.{
                    .BindGameCommand = .{
                        .player_number = self.for_player,
                        .command = command,
                        .source = source,
                    },
                });
                ctx.setSound(.Ding);
                self.rebinding = null;
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

        if (ctx.optionToggle("For player: {}", .{self.for_player + 1})) {
            self.for_player += 1;
            if (self.for_player == config.num_players) {
                self.for_player = 0;
            }
            ctx.setSound(.Ding);
        }

        ctx.vspacer();

        inline for (commands) |command, i| {
            const command_name = @tagName(command) ++ ":" ++ " " ** (longest_command_name - @tagName(command).len);
            self.keyBindingOption(Ctx, ctx, self.for_player, command, command_name);
        }

        ctx.vspacer();

        if (ctx.option("Close", .{})) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }

    fn keyBindingOption(self: *@This(), comptime Ctx: type, ctx: *Ctx, for_player: u32, command: input.GameCommand, command_name: []const u8) void {
        const result =
            if (if (self.rebinding) |rebinding_command| rebinding_command == command else false) (
                ctx.option("{} {}", [_][]const u8 {
                    command_name,
                    switch (ctx.menu_context.anim_time / 16 % 4) {
                        0 => ".  ",
                        1 => ".. ",
                        2 => "...",
                        else => "",
                    },
                })
            ) else if (ctx.menu_context.cfg.game_bindings[for_player][@enumToInt(command)]) |source| (
                switch (source) {
                    .Key => |key|
                        ctx.option("{} {}", .{command_name, key_names[@enumToInt(key)]}),
                    .JoyButton => |j|
                        ctx.option("{} Joy{}Button{}", .{command_name, j.which, j.button}),
                    .JoyAxisPos => |j|
                        ctx.option("{} Joy{}Axis{}+", .{command_name, j.which, j.axis}),
                    .JoyAxisNeg => |j|
                        ctx.option("{} Joy{}Axis{}-", .{command_name, j.which, j.axis}),
                }
            ) else (
                ctx.option("{}", .{command_name})
            );

        if (result) {
            self.rebinding = command;
            ctx.setEffect(.ResetAnimTime);
            ctx.setSound(.Ding);
        }
    }
};

pub const HighScoresMenu = struct {
    cursor_pos: usize,

    pub fn init() @This() {
        return .{
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
            ctx.label("{:3}. {}", .{i + 1, score});
        }

        ctx.vspacer();

        if (ctx.option("Close", .{})) {
            ctx.setEffect(.Pop);
            ctx.setSound(.Ding);
        }
    }
};
