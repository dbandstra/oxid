const assets_path = @import("build_options").assets_path;
const builtin = @import("builtin");
const std = @import("std");
const epoch = @import("epoch");
const Hunk = @import("zig-hunk").Hunk;
const HunkSide = @import("zig-hunk").HunkSide;
const pdraw = @import("root").pdraw;
const pstorage = @import("root").pstorage;
const pstorage_dirname = @import("root").pstorage_dirname;
const ptime = @import("root").ptime;
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
    audio_module: audio.MainModule,
    static: GameStatic,
    session_memory: game.Session, // don't access this directly
    session: ?*game.Session, // points to session_memory when a game is running
    demo_state: DemoState,
    game_over: bool, // if true, leave the game unpaused even when a menu is open
    new_high_score: bool,
    high_scores: [constants.num_high_scores]u32,
    menu_anim_time: u32,
    menu_stack: menus.MenuStack,
    fullscreen: bool,
    canvas_scale: u31,
    max_canvas_scale: u31,
    friendly_fire: bool,
    record_demos: bool,
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
        std.log.crit("Failed to load high scores: {}", .{err});
        break :blk [1]u32{0} ** constants.num_high_scores;
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

    audio.MainModule.init(
        &self.audio_module,
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
    self.record_demos = false;
    self.sound_enabled = params.sound_enabled;
    self.prng = std.rand.DefaultPrng.init(params.random_seed);
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
        .record_demos = self.record_demos,
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
        .toggle_record_demos => {
            self.record_demos = !self.record_demos;
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

const DemoLine = struct {
    storagekey: []const u8,
    player1_score: u32,
    player2_score: u32,
};

fn readDemoIndex(hunk_side: *HunkSide, lines_array: []DemoLine) !usize {
    const maybe_object = try pstorage.ReadableObject.open(hunk_side, "demos.dat");
    var object = maybe_object orelse return 0; // this copies a big static buffer - ouch
    defer object.close();

    var num_lines: usize = 0;
    while (num_lines < lines_array.len) {
        const len = object.reader().readIntLittle(u32) catch |err| {
            if (err == error.EndOfStream)
                break;
            return err;
        };
        const sk = try hunk_side.allocator.alloc(u8, len);
        try object.reader().readNoEof(sk);
        const p1 = try object.reader().readIntLittle(u32);
        const p2 = try object.reader().readIntLittle(u32);
        lines_array[num_lines] = .{
            .storagekey = sk,
            .player1_score = p1,
            .player2_score = p2,
        };
        num_lines += 1;
    }

    return num_lines;
}

fn writeDemoIndex(
    hunk_side: *HunkSide,
    prev_lines: []const DemoLine,
    storagekey: []const u8,
    player1_score: u32,
    player2_score: u32,
) !void {
    var object = try pstorage.WritableObject.open(hunk_side, "demos.dat");
    defer object.close();

    // write the new demo to the file
    try object.writer().writeIntLittle(u32, @intCast(u32, storagekey.len));
    try object.writer().writeAll(storagekey);
    try object.writer().writeIntLittle(u32, player1_score);
    try object.writer().writeIntLittle(u32, player2_score);

    // write up to 9 lines from the previous file contents
    for (prev_lines[0..std.math.min(prev_lines.len, 9)]) |line| {
        try object.writer().writeIntLittle(u32, @intCast(u32, line.storagekey.len));
        try object.writer().writeAll(line.storagekey);
        try object.writer().writeIntLittle(u32, line.player1_score);
        try object.writer().writeIntLittle(u32, line.player2_score);
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

    // update the demo index file
    const mark = self.hunk.low().getMark();
    defer self.hunk.low().freeToMark(mark);

    var demo_lines: [10]DemoLine = undefined;

    // read the demo index. it should contain up to 10 scores.
    const num_demo_lines = readDemoIndex(&self.hunk.low(), &demo_lines) catch |err| blk: {
        std.log.err("Failed to read demo index: {}", .{err});
        break :blk 0;
    };

    // write the demo index back. put the new demo at the top. if there were already
    // 10 demos, leave out the last one.
    writeDemoIndex(
        &self.hunk.low(),
        demo_lines[0..num_demo_lines],
        dr.storagekey,
        player1_score,
        player2_score,
    ) catch |err| {
        std.log.err("Failed to write demo index: {}", .{err});
    };

    // if we just bumped an old demo off the end of the list, delete the actual
    // recording
    if (num_demo_lines == demo_lines.len) {
        const storagekey = demo_lines[demo_lines.len - 1].storagekey;

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

        const epoch_seconds: epoch.EpochSeconds = .{
            .secs = ptime.timestamp(),
        };
        const epoch_day = epoch_seconds.getEpochDay();
        const day_seconds = epoch_seconds.getDaySeconds();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        // note: date and time are UTC, oh well. i don't think zig has timezone capabilities yet.
        _ = try fbs.writer().print("demos/{d:0>4}-{d:0>2}-{d:0>2}_{d:0>2}-{d:0>2}-{d:0>2}.dat", .{
            year_day.year,
            month_day.month.numeric(),
            month_day.day_index + 1,
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
        });

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

    if (self.record_demos) {
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

    game.frameCleanup(gs);
}

pub fn draw(self: *MainState, draw_state: *pdraw.State) void {
    drawGame(draw_state, &self.static, self.session, self.cfg, self.high_scores[0]);
    drawMenu(&self.menu_stack, .{
        .ds = draw_state,
        .static = &self.static,
        .menu_context = makeMenuContext(self),
    });
    pdraw.flush(draw_state);
}

// called when audio thread is locked. this is where we communicate
// information from the main thread to the audio thread.
pub fn audioSync(self: *MainState, reset: bool, sample_rate: f32) void {
    self.audio_module.sync(
        reset,
        self.cfg.volume,
        sample_rate,
        self.session,
        &self.menu_sounds,
    );
}
