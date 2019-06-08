const std = @import("std");
const math = @import("../common/math.zig");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const platform = @import("../platform.zig");
const VWIN_W = @import("../oxid.zig").VWIN_W;
const VWIN_H = @import("../oxid.zig").VWIN_H;
const HUD_HEIGHT = @import("../oxid.zig").HUD_HEIGHT;
const GameState = @import("../oxid.zig").GameState;
const Constants = @import("constants.zig");
const GameSession = @import("game.zig").GameSession;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const GRIDSIZE_PIXELS = @import("level.zig").GRIDSIZE_PIXELS;
const GRIDSIZE_SUBPIXELS = @import("level.zig").GRIDSIZE_SUBPIXELS;
const LEVEL = @import("level.zig").LEVEL;
const c = @import("components.zig");
const perf = @import("perf.zig");
const util = @import("util.zig");

const PRIMARY_FONT_COLOUR_INDEX = 15; // near-white
const HEART_FONT_COLOUR_INDEX = 6; // red
const SKULL_FONT_COLOUR_INDEX = 10; // light grey

pub fn drawGame(g: *GameState) void {
    const mc = g.session.findFirst(c.MainController) orelse return;

    if (mc.game_running_state) |grs| {
        const max_drawables = comptime GameSession.getCapacity(c.EventDraw);
        var sort_buffer: [max_drawables]*const c.EventDraw = undefined;
        const sorted_drawables = getSortedDrawables(g, sort_buffer[0..]);

        platform.drawBegin(&g.draw_state, g.tileset.texture.handle, null);
        drawMap(g);
        drawEntities(g, sorted_drawables);
        drawMapForeground(g);
        platform.drawEnd(&g.draw_state);

        drawBoxes(g);
        drawHud(g, true);

        if (grs.exit_dialog_open) {
            drawExitDialog(g);
        }
    } else {
        platform.drawBegin(&g.draw_state, g.tileset.texture.handle, null);
        drawMap(g);
        platform.drawEnd(&g.draw_state);

        drawHud(g, false);
        drawMainMenu(g);
    }
}

///////////////////////////////////////

fn getSortedDrawables(g: *GameState, sort_buffer: []*const c.EventDraw) []*const c.EventDraw {
    perf.begin(&perf.timers.DrawSort);
    defer perf.end(&perf.timers.DrawSort, g.perf_spam);

    var num_drawables: usize = 0;
    var it = g.session.iter(c.EventDraw); while (it.next()) |object| {
        if (object.is_active) {
            sort_buffer[num_drawables] = &object.data;
            num_drawables += 1;
        }
    }
    var sorted_drawables = sort_buffer[0..num_drawables];
    std.sort.sort(*const c.EventDraw, sorted_drawables, util.lessThanField(*const c.EventDraw, "z_index"));
    return sorted_drawables;
}

fn drawMapTile(g: *GameState, x: u31, y: u31) void {
    const gridpos = math.Vec2.init(x, y);
    if (switch (LEVEL.getGridValue(gridpos).?) {
        0x00 => Graphic.Floor,
        0x80 => Graphic.Wall,
        0x81 => Graphic.Wall2,
        0x82 => Graphic.Pit,
        0x83 => Graphic.EvilWallTL,
        0x84 => Graphic.EvilWallTR,
        0x85 => Graphic.EvilWallBL,
        0x86 => Graphic.EvilWallBR,
        else => null,
    }) |graphic| {
        const pos = math.Vec2.scale(gridpos, GRIDSIZE_SUBPIXELS);
        const dx = @intToFloat(f32, @divFloor(pos.x, math.SUBPIXELS));
        const dy = @intToFloat(f32, @divFloor(pos.y, math.SUBPIXELS)) + HUD_HEIGHT;
        const dw = GRIDSIZE_PIXELS;
        const dh = GRIDSIZE_PIXELS;
        platform.drawTile(
            &g.draw_state,
            &g.tileset,
            getGraphicTile(graphic),
            dx, dy, dw, dh,
            draw.Transform.Identity,
        );
    }
}

fn drawMap(g: *GameState) void {
    perf.begin(&perf.timers.DrawMap);
    defer perf.end(&perf.timers.DrawMap, g.perf_spam);

    var y: u31 = 0; while (y < LEVEL.h) : (y += 1) {
        var x: u31 = 0; while (x < LEVEL.w) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

// make the central 2x2 map tiles a foreground layer, so that the player spawn
// anim makes him arise from behind it. (this should probably be implemented as
// a regular entity later.)
fn drawMapForeground(g: *GameState) void {
    perf.begin(&perf.timers.DrawMapForeground);
    defer perf.end(&perf.timers.DrawMapForeground, g.perf_spam);

    var y: u31 = 6; while (y < 8) : (y += 1) {
        var x: u31 = 9; while (x < 11) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

fn drawEntities(g: *GameState, sorted_drawables: []*const c.EventDraw) void {
    perf.begin(&perf.timers.DrawEntities);
    defer perf.end(&perf.timers.DrawEntities, g.perf_spam);

    for (sorted_drawables) |drawable| {
        const x = @intToFloat(f32, @divFloor(drawable.pos.x, math.SUBPIXELS));
        const y = @intToFloat(f32, @divFloor(drawable.pos.y, math.SUBPIXELS)) + HUD_HEIGHT;
        const w = GRIDSIZE_PIXELS;
        const h = GRIDSIZE_PIXELS;
        platform.drawTile(
            &g.draw_state,
            &g.tileset,
            getGraphicTile(drawable.graphic),
            x, y, w, h,
            drawable.transform,
        );
    }
}

fn drawBoxes(g: *GameState) void {
    var it = g.session.iter(c.EventDrawBox); while (it.next()) |object| {
        if (object.is_active) {
            const abs_bbox = object.data.box;
            const x0 = @intToFloat(f32, @divFloor(abs_bbox.mins.x, math.SUBPIXELS));
            const y0 = @intToFloat(f32, @divFloor(abs_bbox.mins.y, math.SUBPIXELS)) + HUD_HEIGHT;
            const x1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.x + 1, math.SUBPIXELS));
            const y1 = @intToFloat(f32, @divFloor(abs_bbox.maxs.y + 1, math.SUBPIXELS)) + HUD_HEIGHT;
            const w = x1 - x0;
            const h = y1 - y0;
            platform.drawUntexturedRect(
                &g.draw_state,
                x0, y0, w, h,
                object.data.color,
                true,
            );
        }
    }
}

fn getColour(g: *GameState, index: usize) platform.Colour {
    std.debug.assert(index < 16);

    return platform.Colour{
        .r = g.palette[index * 3 + 0],
        .g = g.palette[index * 3 + 1],
        .b = g.palette[index * 3 + 2],
    };
}

fn drawHud(g: *GameState, game_active: bool) void {
    perf.begin(&perf.timers.DrawHud);
    defer perf.end(&perf.timers.DrawHud, g.perf_spam);

    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);

    const mc = g.session.findFirst(c.MainController).?;
    const gc_maybe = g.session.findFirst(c.GameController);
    const pc_maybe = g.session.findFirst(c.PlayerController);

    platform.drawUntexturedRect(
        &g.draw_state,
        0, 0, @intToFloat(f32, VWIN_W), @intToFloat(f32, HUD_HEIGHT),
        draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
        false,
    );

    const fontColour = getColour(g, PRIMARY_FONT_COLOUR_INDEX);
    platform.drawBegin(&g.draw_state, g.font.tileset.texture.handle, fontColour);

    if (gc_maybe) |gc| {
        if (pc_maybe) |pc| {
            const maybe_player_creature =
                if (pc.player_id) |player_id|
                    g.session.find(player_id, c.Creature)
                else
                    null;

            _ = dest.stream.print("Wave:{}", gc.wave_number) catch unreachable; // FIXME
            fontDrawString(&g.draw_state, &g.font, 0, 0, dest.getWritten());
            dest.reset();
            fontDrawString(&g.draw_state, &g.font, 8*8, 0, "Lives:");

            platform.drawEnd(&g.draw_state);
            const heartFontColour = getColour(g, HEART_FONT_COLOUR_INDEX);
            platform.drawBegin(&g.draw_state, g.font.tileset.texture.handle, heartFontColour);
            var i: u31 = 0; while (i < pc.lives) : (i += 1) {
                fontDrawString(&g.draw_state, &g.font, (14+i)*8, 0, "\x1E"); // heart
            }
            platform.drawEnd(&g.draw_state);

            if (pc.lives == 0) {
                const skullFontColour = getColour(g, SKULL_FONT_COLOUR_INDEX);
                platform.drawBegin(&g.draw_state, g.font.tileset.texture.handle, skullFontColour);
                fontDrawString(&g.draw_state, &g.font, 14*8, 0, "\x1F"); // skull
                platform.drawEnd(&g.draw_state);
            }

            platform.drawBegin(&g.draw_state, g.font.tileset.texture.handle, fontColour);

            if (maybe_player_creature) |player_creature| {
                if (player_creature.god_mode) {
                    fontDrawString(&g.draw_state, &g.font, 8*8, 8, "god mode");
                }
            }
            _ = dest.stream.print("Score:{}", pc.score) catch unreachable; // FIXME
            fontDrawString(&g.draw_state, &g.font, 19*8, 0, dest.getWritten());
            dest.reset();
        }

        if (gc.wave_message) |message| {
            if (gc.wave_message_timer > 0) {
                const x = 320 / 2 - message.len * 8 / 2;
                fontDrawString(&g.draw_state, &g.font, @intCast(i32, x), 28*8, message);
            }
        }
    }

    _ = dest.stream.print("High:{}", mc.high_score) catch unreachable; // FIXME
    fontDrawString(&g.draw_state, &g.font, 30*8, 0, dest.getWritten());
    dest.reset();

    platform.drawEnd(&g.draw_state);

    if (if (gc_maybe) |gc| gc.game_over else false) {
        const y = 8*4;

        if (mc.new_high_score) {
            drawTextBox(g, DrawCoord.Centered, DrawCoord{ .Exact = y }, "GAME OVER\n\nNew high score!");
        } else {
            drawTextBox(g, DrawCoord.Centered, DrawCoord{ .Exact = y }, "GAME OVER");
        }
    }
}

fn drawExitDialog(g: *GameState) void {
    drawTextBox(g, DrawCoord.Centered, DrawCoord.Centered, "Leave game? [Y/N]");
}

fn drawMainMenu(g: *GameState) void {
    drawTextBox(g, DrawCoord.Centered, DrawCoord.Centered, "OXID\n\n[Space] to play\n\n[Esc] to quit");
}

const DrawCoord = union(enum){
    Centered,
    Exact: i32,
};

fn drawTextBox(g: *GameState, dx: DrawCoord, dy: DrawCoord, text: []const u8) void {
    var tw: u31 = 0;
    var th: u31 = 1;

    {
        var tx: u31 = 0;
        for (text) |ch| {
            if (ch == '\n') {
                tx = 0;
                th += 1;
            } else {
                tx += 1;
                if (tx > tw) {
                    tw = tx;
                }
            }
        }
    }

    const w = 8 * (tw + 2);
    const h = 8 * (th + 2);

    const x = switch (dx) {
        DrawCoord.Centered => i32(VWIN_W / 2 - w / 2),
        DrawCoord.Exact => |x| x,
    };
    const y = switch (dy) {
        DrawCoord.Centered => i32(VWIN_H / 2 - h / 2),
        DrawCoord.Exact => |y| y,
    };

    platform.drawUntexturedRect(
        &g.draw_state,
        @intToFloat(f32, x), @intToFloat(f32, y),
        @intToFloat(f32, w), @intToFloat(f32, h),
        draw.Color{ .r = 0, .g = 0, .b = 0, .a = 255 },
        false,
    );

    const fontColour = getColour(g, PRIMARY_FONT_COLOUR_INDEX);
    platform.drawBegin(&g.draw_state, g.font.tileset.texture.handle, fontColour);
    {
        var start: usize = 0;
        var sy = y + 8;
        var i: usize = 0; while (i <= text.len) : (i += 1) {
            if (i == text.len or text[i] == '\n') {
                const slice = text[start..i];
                const sw = 8 * @intCast(u31, slice.len);
                const sx = x + i32(w / 2 - sw / 2);
                fontDrawString(&g.draw_state, &g.font, sx, sy, slice);
                sy += 8;
                start = i + 1;
            }
        }
    }
    platform.drawEnd(&g.draw_state);
}
