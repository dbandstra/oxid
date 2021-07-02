const assets_path = @import("build_options").assets_path;
const builtin = @import("builtin");
const std = @import("std");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const pdate = @import("root").pdate;
const pdraw = @import("root").pdraw;
const pstorage = @import("root").pstorage;
const pstorage_dirname = @import("root").pstorage_dirname;
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
const demos = @import("demos.zig");

// this many pixels is added to the top of the window for font stuff
pub const hud_height = 16;

// size of the virtual screen. the actual window size will be an integer
// multiple of this
pub const vwin_w = levels.width * levels.pixels_per_tile; // 320
pub const vwin_h = levels.height * levels.pixels_per_tile + hud_height; // 240

pub const DemoIndexEntry = struct {
    storagekey_buffer: [256]u8,
    storagekey_len: u8,
    player1_score: u32,
    player2_score: u32,
};

pub const DemoRecording = struct {
    storagekey_buffer: [256]u8,
    storagekey: []const u8,
    object: pstorage.WritableObject,
    recorder: demos.Recorder,
};

pub const DemoPlaying = struct {
    object: pstorage.ReadableObject,
    player: demos.Player,
};

pub const DemoState = union(enum) {
    no_demo,
    recording: DemoRecording,
    playing: DemoPlaying,
};

pub const MainState = struct {
    hunk: *Hunk,
    cfg: config.Config,
    audio_state: audio.State,
    static: GameStatic,
    session_memory: game.Session, // don't access this directly
    session: ?*game.Session, // points to session_memory when a game is running
    demo_state: DemoState,
    game_over: bool, // if true, leave the game unpaused even when a menu is open
    new_high_score: bool,
    high_scores: [constants.num_high_scores]u32,
    demo_index: [constants.num_demo_index_entries]DemoIndexEntry,
    demo_index_num: usize,
    menu_anim_time: u32,
    menu_stack: menus.MenuStack,
    fullscreen: bool,
    canvas_scale: u31,
    max_canvas_scale: u31,
    friendly_fire: bool,
    disable_recording: bool,
    sound_enabled: bool,
    prng: std.rand.DefaultPrng,
    queued_menu_sound: ?audio.SoundParams,
};

pub const GameStatic = struct {
    tileset: drawing.Tileset,
    palette: [48]u8,
    font: fonts.Font,
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
    disable_recording: bool,
};

pub fn init(self: *MainState, ds: *pdraw.State, params: InitParams) !void {
    self.hunk = params.hunk;

    self.high_scores = loadHighScores(&self.hunk.low()) catch |err| blk: {
        // the file exists but there was an error loading it. just continue
        // with an empty high scores list, even though that might mean that
        // the user's legitimate high scores might get wiped out (FIXME?)
        std.log.crit("Failed to load high scores: {}", .{err});
        break :blk [1]u32{0} ** constants.num_high_scores;
    };

    readDemoIndex(self) catch |err| {
        std.log.crit("Failed to load demo index: {}", .{err});
    };

    fonts.load(ds, &self.hunk.low(), &self.static.font, .{
        .filename = assets_path ++ "/font.pcx",
        .first_char = 0,
        .char_width = 8,
        .char_height = 8,
        .spacing = -2,
    }) catch |err| {
        std.log.emerg("Failed to load font: {}", .{err});
        return error.Failed;
    };
    errdefer fonts.unload(&self.static.font);

    graphics.loadTileset(ds, &self.hunk.low(), &self.static.tileset, &self.static.palette) catch |err| {
        std.log.emerg("Failed to load tileset: {}", .{err});
        return error.Failed;
    };
    errdefer graphics.unloadTileset(&self.static.tileset);

    self.cfg = config.read(&self.hunk.low(), storagekey_config) catch |err| blk: {
        std.log.crit("Failed to load config: {}", .{err});
        break :blk config.getDefault();
    };

    audio.State.init(
        &self.audio_state,
        self.hunk,
        self.cfg.volume,
        params.audio_sample_rate,
        params.audio_buffer_size,
    ) catch |err| {
        std.log.emerg("Failed to load audio module: {}", .{err});
        return error.Failed;
    };

    perf.init();

    // self.session_memory is undefined until a game is actually started
    self.session = null;
    self.demo_state = .no_demo;
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
    self.disable_recording = params.disable_recording;
    self.prng = std.rand.DefaultPrng.init(params.random_seed);
    self.queued_menu_sound = null;
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
        .demo_index = self.demo_index[0..self.demo_index_num],
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
            self.queued_menu_sound = .menu_backoff;
        },
        .blip => {
            self.queued_menu_sound = .{ .menu_blip = .{ .freq_mul = 0.95 + 0.1 * self.prng.random.float(f32) } };
        },
        .ding => {
            self.queued_menu_sound = .menu_ding;
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
    // menu command?
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
    if (main_state.demo_state == .playing)
        return null;

    const gs = main_state.session orelse return null;
    const gc = gs.ecs.componentIter(c.GameController).next() orelse return null;

    var player_number: u32 = 0;
    while (player_number < config.num_players) : (player_number += 1) {
        for (main_state.cfg.game_bindings[player_number]) |maybe_source, i| {
            const s = maybe_source orelse continue;
            if (!inputs.Source.eql(s, source)) continue;

            const player_controller_id = switch (player_number) {
                0 => gc.player1_controller_id,
                1 => gc.player2_controller_id orelse continue,
                else => continue,
            };

            const command = @intToEnum(commands.GameCommand, @intCast(@TagType(commands.GameCommand), i));
            p.spawnEventGameInput(gs, .{
                .player_controller_id = player_controller_id,
                .command = command,
                .down = down,
            });

            switch (main_state.demo_state) {
                .recording => |*dr| {
                    dr.recorder.recordInput(dr.object.writer(), player_number, command, down) catch |err| {
                        std.log.err("Aborting demo recording due to error: {}", .{err});
                        dr.object.close();
                        main_state.demo_state = .no_demo;
                    };
                },
                else => {},
            }

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
            startGame(self, is_multiplayer);
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
        .play_demo => |index| {
            if (index < self.demo_index_num) {
                const entry = &self.demo_index[index];
                playDemo(self, entry.storagekey_buffer[0..entry.storagekey_len]);
            }
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
            if (self.session) |gs| {
                setFriendlyFire(gs, self.friendly_fire);
            }
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

fn resetDemo(self: *MainState) void {
    switch (self.demo_state) {
        .no_demo => {},
        .playing => |*dp| {
            dp.object.close();
            self.demo_state = .no_demo;
        },
        .recording => |*dr| {
            dr.object.close();
            self.demo_state = .no_demo;
        },
    }
}

fn readDemoIndex(self: *MainState) !void {
    self.demo_index_num = 0;

    var object = (try pstorage.ReadableObject.open(&self.hunk.low(), "demos.dat")) orelse return;
    defer object.close();

    errdefer self.demo_index_num = 0;

    while (self.demo_index_num < self.demo_index.len) {
        const len = object.reader().readByte() catch |err| {
            if (err == error.EndOfStream)
                break;
            return err;
        };

        const entry = &self.demo_index[self.demo_index_num];
        self.demo_index_num += 1;

        try object.reader().readNoEof(entry.storagekey_buffer[0..len]);
        entry.storagekey_len = len;
        entry.player1_score = try object.reader().readIntLittle(u32);
        entry.player2_score = try object.reader().readIntLittle(u32);
    }
}

fn writeDemoIndex(self: *MainState) !void {
    var object = try pstorage.WritableObject.open(&self.hunk.low(), "demos.dat");
    defer object.close();

    for (self.demo_index[0..self.demo_index_num]) |entry| {
        try object.writer().writeByte(entry.storagekey_len);
        try object.writer().writeAll(entry.storagekey_buffer[0..entry.storagekey_len]);
        try object.writer().writeIntLittle(u32, entry.player1_score);
        try object.writer().writeIntLittle(u32, entry.player2_score);
    }
}

fn finishDemoRecording(self: *MainState, player1_score: u32, player2_score: u32) void {
    const dr = switch (self.demo_state) {
        .recording => |*dr_| dr_,
        else => return,
    };

    defer self.demo_state = .no_demo;

    // finalize the demo recording
    {
        defer dr.object.close();

        dr.recorder.end(
            dr.object.writer(),
            dr.object.seekableStream(),
            player1_score,
            player2_score,
        ) catch |err| {
            std.log.err("Aborting demo recording due to error: {}", .{err});
            return;
        };

        std.log.notice("Finished recording.", .{});
    }

    // read the demo index again (we already read it when the program started
    // up), just to make sure we're up to date.
    readDemoIndex(self) catch |err| {
        std.log.err("Failed to read demo index: {}", .{err});
    };

    // remember the key of the old demo to delete
    const maybe_entry_to_delete =
        if (self.demo_index_num == self.demo_index.len)
        self.demo_index[self.demo_index.len - 1]
    else
        null;

    // add the new score to the demo index
    if (self.demo_index_num < self.demo_index.len) {
        self.demo_index_num += 1;
    }
    var i = self.demo_index_num - 1;
    while (i > 0) : (i -= 1) {
        self.demo_index[i] = self.demo_index[i - 1];
    }
    std.mem.copy(u8, &self.demo_index[0].storagekey_buffer, dr.storagekey);
    self.demo_index[0].storagekey_len = @intCast(u8, dr.storagekey.len);
    self.demo_index[0].player1_score = player1_score;
    self.demo_index[0].player2_score = player2_score;

    // save the demo index
    writeDemoIndex(self) catch |err| {
        std.log.err("Failed to write demo index: {}", .{err});
    };

    // if we just bumped an old demo off the end of the list, delete the actual
    // recording
    if (maybe_entry_to_delete) |entry| {
        const storagekey = entry.storagekey_buffer[0..entry.storagekey_len];
        pstorage.deleteObject(&self.hunk.low(), storagekey) catch |err| {
            std.log.err("Failed to delete old demo: {}", .{err});
        };
    }
}

fn startRecording(self: *MainState, seed: u32, is_multiplayer: bool) !void {
    std.debug.assert(self.demo_state == .no_demo);

    self.demo_state = .{ .recording = undefined };
    errdefer self.demo_state = .no_demo;

    const dr = switch (self.demo_state) {
        .recording => |*dr| dr,
        else => unreachable,
    };

    dr.storagekey = blk: {
        var fbs = std.io.fixedBufferStream(&dr.storagekey_buffer);

        _ = try fbs.writer().print("demos/", .{});
        try pdate.getDateTime(fbs.writer());
        _ = try fbs.writer().print(".dat", .{});

        break :blk fbs.getWritten();
    };

    dr.object = try pstorage.WritableObject.open(&self.hunk.low(), dr.storagekey);
    errdefer dr.object.close();

    try dr.recorder.start(dr.object.writer(), seed, is_multiplayer);

    std.log.notice("Recording to {}", .{dr.storagekey});
}

// called when "start new game" is selected in the menu. if a game is already
// in progress, restart it
fn startGame(self: *MainState, is_multiplayer: bool) void {
    resetDemo(self);

    const seed = self.prng.random.int(u32);

    if (!self.disable_recording) {
        startRecording(self, seed, is_multiplayer) catch |err| {
            std.log.err("Failed to start demo recording: {}", .{err});
        };
    }

    self.menu_stack.clear();

    const gs = &self.session_memory;

    game.init(gs, seed, is_multiplayer);

    self.session = gs;
}

fn startPlaying(self: *MainState, storagekey: []const u8) !*const demos.Player {
    std.debug.assert(self.demo_state == .no_demo);

    self.demo_state = .{ .playing = undefined };
    errdefer self.demo_state = .no_demo;

    const dp = switch (self.demo_state) {
        .playing => |*dp_| dp_,
        else => unreachable,
    };

    dp.object = (try pstorage.ReadableObject.open(&self.hunk.low(), storagekey)) orelse {
        return error.DemoNotFound;
    };
    errdefer dp.object.close();

    dp.player = try demos.Player.start(dp.object.reader());

    std.log.notice("Playing demo from {s}", .{storagekey});

    return &dp.player;
}

pub fn playDemo(self: *MainState, storagekey: []const u8) void {
    resetDemo(self);

    const player = startPlaying(self, storagekey) catch |err| {
        std.log.err("Failed to open demo player: {}", .{err});
        return;
    };

    self.menu_stack.clear();

    const gs = &self.session_memory;

    game.init(gs, player.game_seed, player.is_multiplayer);

    self.session = gs;
}

// clear out all existing game state and open the main menu. this should leave
// the program in a similar state to when it was first started up.
fn resetGame(self: *MainState) void {
    resetDemo(self);

    self.session = null;

    self.menu_stack.clear();
    self.menu_stack.push(.{
        .main_menu = menus.MainMenu.init(),
    });
}

fn postScores(self: *MainState) void {
    const gs = self.session orelse return;

    if (self.demo_state == .playing) {
        // this is a demo playback, don't post the score
        return;
    }

    self.new_high_score = false;

    var save_high_scores = false;

    var player1_score: u32 = 0;
    var player2_score: u32 = 0;

    // get players' scores
    var it = gs.ecs.componentIter(c.PlayerController);
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

        switch (pc.color) {
            .yellow => player1_score = pc.score,
            .green => player2_score = pc.score,
        }
    }

    if (save_high_scores) {
        saveHighScores(&self.hunk.low(), self.high_scores) catch |err| {
            std.log.err("Failed to save high scores: {}", .{err});
        };
    }

    finishDemoRecording(self, player1_score, player2_score);
}

pub fn frame(self: *MainState, frame_context: game.FrameContext) void {
    self.menu_anim_time +%= 1;

    const paused = self.menu_stack.len > 0 and !self.game_over;

    const gs = self.session orelse return;

    // TODO filter out `esc` commands?
    // also if menu is open don't record arrows (not sure if that's happening)

    if (!paused) {
        switch (self.demo_state) {
            .no_demo, .recording => {},
            .playing => |*dp| {
                while (dp.player.getNextEvent()) |event| {
                    switch (event) {
                        .end_of_demo => {
                            std.log.notice("Demo playback complete.", .{});
                            resetGame(self);
                            return;
                        },
                        .input => |input| {
                            const gc = gs.ecs.componentIter(c.GameController).next() orelse break;
                            const player_controller_id = switch (input.player_index) {
                                0 => gc.player1_controller_id,
                                1 => gc.player2_controller_id,
                                else => null,
                            } orelse continue;
                            p.spawnEventGameInput(gs, .{
                                .player_controller_id = player_controller_id,
                                .command = input.command,
                                .down = input.down,
                            });
                        },
                    }
                    dp.player.readNextInput(dp.object.reader()) catch |err| {
                        std.log.err("Demo playback error: {}", .{err});
                        resetGame(self);
                        return;
                    };
                }
            },
        }
    }

    perf.begin(.frame);
    game.frame(gs, frame_context, paused);
    perf.end(.frame);

    if (!paused) {
        switch (self.demo_state) {
            .no_demo => {},
            .playing => |*dp| {
                dp.player.incrementFrameIndex() catch |err| {
                    std.log.err("Demo playback error: {}", .{err});
                    resetGame(self);
                    return;
                };
            },
            .recording => |*dr| {
                dr.recorder.incrementFrameIndex(dr.object.writer()) catch |err| {
                    std.log.err("Aborting demo recording due to error: {}", .{err});
                    dr.object.close();
                    self.demo_state = .no_demo;
                };
            },
        }
    }

    // if EventGameOver is present, post the high score, but leave the
    // monsters running around. (the game state will be cleared when the user
    // hits escape again.)
    if (gs.ecs.componentIter(c.EventGameOver).next() != null) {
        self.game_over = true;
        postScores(self);

        self.menu_stack.push(.{
            .game_over_menu = menus.GameOverMenu.init(),
        });
    }

    // note: caller still needs to call `game.frameCleanup`
}

pub fn frameCleanup(self: *MainState) void {
    const gs = self.session orelse return;

    // this removes all event entities except for EventPlaySound (those will
    // be removed by audioSync as they're consumed).
    game.frameCleanup(gs);
}

pub fn draw(self: *MainState, draw_state: *pdraw.State) void {
    const maybe_demo_progress = switch (self.demo_state) {
        .playing => |*dp| if (dp.player.total_frames > 0)
            dp.player.frame_index * 100 / dp.player.total_frames
        else
            0,
        else => null,
    };
    drawGame(
        draw_state,
        &self.static,
        self.session,
        self.cfg,
        self.high_scores[0],
        maybe_demo_progress,
    );
    drawMenu(&self.menu_stack, .{
        .ds = draw_state,
        .static = &self.static,
        .menu_context = makeMenuContext(self),
    });
    pdraw.flush(draw_state);
}

// called when audio thread is locked. this is where we communicate
// information from the main thread to the audio thread.
pub fn audioSync(self: *MainState, new_sample_rate: ?f32) void {
    self.audio_state.volume = self.cfg.volume;
    if (new_sample_rate) |sample_rate|
        self.audio_state.sample_rate = sample_rate;

    // if sound is disabled, clear out any lingering state from before it was disabled
    if (!self.sound_enabled)
        self.audio_state.reset();

    // push menu sounds
    if (self.queued_menu_sound) |params| {
        if (self.sound_enabled)
            self.audio_state.pushSound(params);
        self.queued_menu_sound = null;
    }

    // push game sounds
    if (self.session) |gs| {
        if (self.sound_enabled) {
            var it = gs.ecs.componentIter(c.EventPlaySound);
            while (it.next()) |event|
                self.audio_state.pushSound(event.params);
        }
        game.soundEventCleanup(gs);
    }
}
