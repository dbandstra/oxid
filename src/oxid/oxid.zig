const assets_path = @import("build_options").assets_path;
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const pdraw = @import("root").pdraw;
const plog = @import("root").plog;
const pstorage = @import("root").pstorage;
const storagekey_config = @import("root").storagekey_config;
const storagekey_highscores = @import("root").storagekey_highscores;
const drawing = @import("../common/drawing.zig");
const fonts = @import("../common/fonts.zig");
const inputs = @import("../common/inputs.zig");
const graphics = @import("graphics.zig");
const perf = @import("perf.zig");
const config = @import("config.zig");
const constants = @import("constants.zig");
const game = @import("game.zig");
const commands = @import("commands.zig");
const levels = @import("levels.zig");
const p = @import("prototypes.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
const menuInput = @import("menu_input.zig").menuInput;
const audio = @import("audio.zig");
const drawMenu = @import("draw_menu.zig").drawMenu;
const drawGame = @import("draw.zig").drawGame;
const setFriendlyFire = @import("functions/set_friendly_fire.zig").setFriendlyFire;

// this many pixels is added to the top of the window for font stuff
pub const hud_height = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const vwin_w = levels.width * levels.pixels_per_tile; // 320
pub const vwin_h = levels.height * levels.pixels_per_tile + hud_height; // 240

pub const MainState = struct {
    hunk: *Hunk,
    cfg: config.Config,
    audio_module: audio.MainModule,
    static: GameStatic,
    session: game.Session,
    game_over: bool, // if true, leave the game unpaused even when a menu is open
    new_high_score: bool,
    high_scores: [constants.num_high_scores]u32,
    menu_anim_time: u32,
    menu_stack: menus.MenuStack,
    fullscreen: bool,
    canvas_scale: u31,
    max_canvas_scale: u31,
    friendly_fire: bool,
    sound_enabled: bool,
    prng: std.rand.DefaultPrng,
    menu_sounds: MenuSounds,
};

pub const GameStatic = struct {
    tileset: drawing.Tileset,
    palette: [48]u8,
    font: fonts.Font,
};

pub const MenuSounds = struct {
    backoff: ?audio.MenuBackoffVoice.NoteParams,
    blip: ?audio.MenuBlipVoice.NoteParams,
    ding: ?audio.MenuDingVoice.NoteParams,
};

pub const InitParams = struct {
    hunk: *Hunk,
    random_seed: u32,
    audio_buffer_size: usize,
    audio_sample_rate: f32,
    fullscreen: bool,
    canvas_scale: u31,
    max_canvas_scale: u31,
    sound_enabled: bool,
};

pub fn init(self: *MainState, ds: *pdraw.State, params: InitParams) !void {
    self.hunk = params.hunk;

    self.high_scores = loadHighScores(&self.hunk.low()) catch |err| blk: {
        // the file exists but there was an error loading it. just continue
        // with an empty high scores list, even though that might mean that
        // the user's legitimate high scores might get wiped out (FIXME?)
        plog.warn("Failed to load high scores: {}\n", .{err});
        break :blk [1]u32{0} ** constants.num_high_scores;
    };

    fonts.load(ds, &self.hunk.low(), &self.static.font, .{
        .filename = assets_path ++ "/font.pcx",
        .first_char = 0,
        .char_width = 8,
        .char_height = 8,
        .num_cols = 16,
        .num_rows = 8,
        .spacing = -1,
    }) catch |err| {
        plog.warn("Failed to load font: {}\n", .{err});
        return error.Failed;
    };
    errdefer fonts.unload(&self.static.font);

    graphics.loadTileset(ds, &self.hunk.low(), &self.static.tileset, &self.static.palette) catch |err| {
        plog.warn("Failed to load tileset: {}\n", .{err});
        return error.Failed;
    };
    errdefer graphics.unloadTileset(&self.static.tileset);

    self.cfg = config.read(&self.hunk.low(), storagekey_config) catch |err| blk: {
        plog.warn("Failed to load config: {}\n", .{err});
        break :blk config.getDefault();
    };

    game.init(&self.session, params.random_seed);

    audio.MainModule.init(
        &self.audio_module,
        self.hunk,
        self.cfg.volume,
        params.audio_sample_rate,
        params.audio_buffer_size,
    ) catch |err| {
        plog.warn("Failed to load audio module: {}\n", .{err});
        return error.Failed;
    };

    perf.init();

    self.game_over = false;
    self.new_high_score = false;
    self.menu_anim_time = 0;
    self.menu_stack = .{
        .array = undefined,
        .len = 1,
    };
    self.menu_stack.array[0] = .{
        .main_menu = menus.MainMenu.init(),
    };
    self.fullscreen = params.fullscreen;
    self.canvas_scale = params.canvas_scale;
    self.max_canvas_scale = params.max_canvas_scale;
    self.friendly_fire = true;
    self.sound_enabled = params.sound_enabled;
    self.prng = std.rand.DefaultPrng.init(0);
    self.menu_sounds = .{
        .backoff = null,
        .blip = null,
        .ding = null,
    };
}

pub fn deinit(self: *MainState) void {
    graphics.unloadTileset(&self.static.tileset);
    fonts.unload(&self.static.font);
}

fn loadHighScores(hunk_side: *HunkSide) ![constants.num_high_scores]u32 {
    var maybe_object = try pstorage.ReadableObject.open(hunk_side, storagekey_highscores);
    var object = maybe_object orelse return [1]u32{0} ** constants.num_high_scores;
    defer object.close();

    var reader = object.reader();
    var high_scores = [1]u32{0} ** constants.num_high_scores;
    var i: usize = 0;
    while (i < constants.num_high_scores) : (i += 1) {
        const score = reader.readIntLittle(u32) catch break;
        high_scores[i] = score;
    }
    return high_scores;
}

fn saveHighScores(hunk_side: *HunkSide, high_scores: [constants.num_high_scores]u32) !void {
    var object = try pstorage.WritableObject.open(hunk_side, storagekey_highscores);
    defer object.close();

    var writer = object.writer();
    for (high_scores) |score| {
        writer.writeIntLittle(u32, score) catch break;
    }
}

pub fn makeMenuContext(self: *const MainState) menus.MenuContext {
    return .{
        .sound_enabled = self.sound_enabled,
        .fullscreen = self.fullscreen,
        .cfg = self.cfg,
        .high_scores = self.high_scores,
        .new_high_score = self.new_high_score,
        .game_over = self.game_over,
        .anim_time = self.menu_anim_time,
        .canvas_scale = self.canvas_scale,
        .max_canvas_scale = self.max_canvas_scale,
        .friendly_fire = self.friendly_fire,
    };
}

fn playMenuSound(self: *MainState, sound: menus.Sound) void {
    switch (sound) {
        .backoff => {
            self.menu_sounds.backoff = .{};
        },
        .blip => {
            self.menu_sounds.blip = .{ .freq_mul = 0.95 + 0.1 * self.prng.random.float(f32) };
        },
        .ding => {
            self.menu_sounds.ding = .{};
        },
    }
}

pub const InputSpecial = union(enum) {
    noop,
    quit,
    toggle_sound,
    toggle_fullscreen,
    set_canvas_scale: u31,
    config_updated,
};

pub fn inputEvent(main_state: *MainState, source: inputs.Source, down: bool) ?InputSpecial {
    if (down) {
        const maybe_menu_command = for (main_state.cfg.menu_bindings) |maybe_source, i| {
            const s = maybe_source orelse continue;
            if (!inputs.Source.eql(s, source)) continue;
            break @intToEnum(commands.MenuCommand, @intCast(@TagType(commands.MenuCommand), i));
        } else null;

        // if menu is open, input goes to it
        if (main_state.menu_stack.len > 0) {
            // note that the menu receives input even if the menu_command is null
            // (used by the key rebinding menu)
            if (menuInput(&main_state.menu_stack, .{
                .source = source,
                .maybe_command = maybe_menu_command,
                .menu_context = makeMenuContext(main_state),
            })) |result| {
                if (result.sound) |sound| {
                    playMenuSound(main_state, sound);
                }
                return applyMenuEffect(main_state, result.effect);
            }
            return null;
        }

        // menu is not open, but should we open it?
        if (maybe_menu_command) |menu_command| {
            if (menu_command == .escape) {
                // assuming that if the menu isn't open, we must be in game
                playMenuSound(main_state, .backoff);
                return applyMenuEffect(main_state, .{
                    .push = .{ .in_game_menu = menus.InGameMenu.init() },
                });
            }
        }
    }

    // game command?
    var player_number: u32 = 0;
    while (player_number < config.num_players) : (player_number += 1) {
        for (main_state.cfg.game_bindings[player_number]) |maybe_source, i| {
            const s = maybe_source orelse continue;
            if (!inputs.Source.eql(s, source)) continue;

            p.spawnEventGameInput(&main_state.session, .{
                .player_number = player_number,
                .command = @intToEnum(commands.GameCommand, @intCast(@TagType(commands.GameCommand), i)),
                .down = down,
            });

            return InputSpecial{ .noop = {} };
        }
    }

    return null;
}

fn applyMenuEffect(self: *MainState, effect: menus.Effect) ?InputSpecial {
    switch (effect) {
        .noop => {},
        .push => |new_menu| {
            self.menu_stack.push(new_menu);
        },
        .pop => {
            self.menu_stack.pop();
        },
        .start_new_game => |is_multiplayer| {
            self.menu_stack.clear();
            startGame(&self.session, is_multiplayer);
            self.game_over = false;
            self.new_high_score = false;
        },
        .end_game => {
            // user ended a running game using the menu.
            postScores(self);
            resetGame(self);
        },
        .reset_game => {
            // user got "game over" and now pressed escape to go back to the main menu.
            // scores were already been posted when the game ended
            resetGame(self);
        },
        .toggle_sound => {
            return InputSpecial{ .toggle_sound = {} };
        },
        .set_volume => |value| {
            self.cfg.volume = value;
            return InputSpecial{ .config_updated = {} };
        },
        .set_canvas_scale => |value| {
            return InputSpecial{ .set_canvas_scale = value };
        },
        .toggle_fullscreen => {
            return InputSpecial{ .toggle_fullscreen = {} };
        },
        .toggle_friendly_fire => {
            self.friendly_fire = !self.friendly_fire;
            // update existing bullets
            setFriendlyFire(&self.session, self.friendly_fire);
        },
        .bind_game_command => |payload| {
            const bindings = &self.cfg.game_bindings[payload.player_number];
            // don't bind if there is already another action bound to this key
            const in_use = if (payload.source) |new_source| for (bindings) |maybe_source| {
                const source = maybe_source orelse continue;
                if (!inputs.Source.eql(source, new_source)) continue;
                break true;
            } else false else false;
            if (!in_use) {
                const command_index = @enumToInt(payload.command);
                bindings[command_index] = payload.source;
                return InputSpecial{ .config_updated = {} };
            }
        },
        .reset_anim_time => {
            self.menu_anim_time = 0;
        },
        .quit => {
            return InputSpecial{ .quit = {} };
        },
    }

    return InputSpecial{ .noop = {} };
}

// called when "start new game" is selected in the menu. if a game is already
// in progress, restart it
fn startGame(gs: *game.Session, is_multiplayer: bool) void {
    // remove all entities
    inline for (@typeInfo(game.ComponentLists).Struct.fields) |field| {
        gs.ecs.markAllForRemoval(field.field_type.ComponentType);
    }

    // set game running state
    gs.running_state = .{
        .render_move_boxes = false,
    };

    // spawn GameController and PlayerControllers
    const num_players: u32 = if (is_multiplayer) 2 else 1;

    _ = p.spawnGameController(gs, .{
        .num_players = num_players,
    });

    var n: u32 = 0;
    while (n < num_players) : (n += 1) {
        _ = p.spawnPlayerController(gs, .{
            .player_number = n,
        });
    }
}

// clear out all existing game state and open the main menu. this should leave
// the program in a similar state to when it was first started up.
fn resetGame(self: *MainState) void {
    self.session.running_state = null;

    // remove all entities
    inline for (@typeInfo(game.ComponentLists).Struct.fields) |field| {
        self.session.ecs.markAllForRemoval(field.field_type.ComponentType);
    }

    self.menu_stack.clear();
    self.menu_stack.push(.{
        .main_menu = menus.MainMenu.init(),
    });
}

fn postScores(self: *MainState) void {
    self.new_high_score = false;

    var save_high_scores = false;

    // get players' scores
    var it = self.session.ecs.componentIter(c.PlayerController);
    while (it.next()) |pc| {
        // insert the score somewhere in the high score list
        const new_score = pc.score;

        // the list is always sorted highest to lowest
        var i: usize = 0;
        while (i < constants.num_high_scores) : (i += 1) {
            if (new_score <= self.high_scores[i]) {
                continue;
            }

            // insert the new score here
            std.mem.copyBackwards(
                u32,
                self.high_scores[i + 1 .. constants.num_high_scores],
                self.high_scores[i .. constants.num_high_scores - 1],
            );

            self.high_scores[i] = new_score;
            if (i == 0) {
                self.new_high_score = true;
            }

            save_high_scores = true;
            break;
        }
    }

    if (save_high_scores) {
        saveHighScores(&self.hunk.low(), self.high_scores) catch |err| {
            plog.warn("Failed to save high scores: {}\n", .{err});
        };
    }
}

pub fn frame(self: *MainState, frame_context: game.FrameContext) void {
    const paused = self.menu_stack.len > 0 and !self.game_over;

    perf.begin(.frame);
    game.frame(&self.session, frame_context, paused);
    perf.end(.frame);

    // if EventGameOver is present, post the high score, but leave the
    // monsters running around. (the game state will be cleared when the user
    // hits escape again.)
    if (self.session.ecs.findFirstComponent(c.EventGameOver) != null) {
        self.game_over = true;
        postScores(self);

        self.menu_stack.push(.{
            .game_over_menu = menus.GameOverMenu.init(),
        });
    }

    // note: caller still needs to call `game.frameCleanup`
}

pub fn draw(self: *MainState, draw_state: *pdraw.State) void {
    drawGame(draw_state, &self.static, &self.session, self.cfg, self.high_scores[0]);
    drawMenu(&self.menu_stack, .{
        .ds = draw_state,
        .static = &self.static,
        .menu_context = makeMenuContext(self),
    });
    pdraw.flush(draw_state);
}