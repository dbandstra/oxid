const builtin = @import("builtin");
const std = @import("std");
const pdraw = @import("pdraw");
const math = @import("../common/math.zig");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const vwin_w =
    if (builtin.arch == .wasm32)
        @import("../oxid_web.zig").virtual_window_width
    else
        @import("../oxid.zig").virtual_window_width;
const vwin_h =
    if (builtin.arch == .wasm32)
        @import("../oxid_web.zig").virtual_window_height
    else
        @import("../oxid.zig").virtual_window_height;
const hud_height =
    if (builtin.arch == .wasm32)
        @import("../oxid_web.zig").hud_height
    else
        @import("../oxid.zig").hud_height;
const GameState =
    if (builtin.arch == .wasm32)
        @import("../oxid_web.zig").GameState
    else
        @import("../oxid.zig").GameState;
const Constants = @import("constants.zig");
const GameSession = @import("game.zig").GameSession;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const levels = @import("levels.zig");
const config = @import("config.zig");
const c = @import("components.zig");
const menus = @import("menus.zig");
//const perf = @import("perf.zig");
const util = @import("util.zig");
const drawMenu = @import("draw_menu.zig").drawMenu;
const drawGameOverOverlay = @import("draw_menu.zig").drawGameOverOverlay;

const primary_font_color_index = 15; // near-white
const heart_font_color_index = 6; // red
const skull_font_color_index = 10; // light grey

pub fn drawGame(g: *GameState, cfg: config.Config) void {
    const mc = g.session.findFirst(c.MainController) orelse return;

    if (mc.game_running_state) |grs| {
        const max_drawables = comptime GameSession.getCapacity(c.EventDraw);
        var sort_buffer: [max_drawables]*const c.EventDraw = undefined;
        const sorted_drawables = getSortedDrawables(g, sort_buffer[0..]);

        pdraw.begin(&g.draw_state, g.tileset.texture.handle, null, 1.0, false);
        drawMap(g);
        drawEntities(g, sorted_drawables);
        drawMapForeground(g);
        pdraw.end(&g.draw_state);

        drawBoxes(g);
        drawHud(g, true);
    } else {
        pdraw.begin(&g.draw_state, g.tileset.texture.handle, null, 1.0, false);
        drawMap(g);
        pdraw.end(&g.draw_state);

        drawHud(g, false);
    }

    if (mc.menu_stack_len > 0) {
        drawMenu(g, cfg, mc, mc.menu_stack_array[mc.menu_stack_len - 1]);
    }
}

///////////////////////////////////////

fn getSortedDrawables(g: *GameState, sort_buffer: []*const c.EventDraw) []*const c.EventDraw {
    //perf.begin(&perf.timers.DrawSort);
    //defer perf.end(&perf.timers.DrawSort, g.perf_spam);

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
    if (switch (levels.level1.getGridValue(gridpos).?) {
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
        const pos = math.Vec2.scale(gridpos, levels.subpixels_per_tile);
        const dx = @divFloor(pos.x, levels.subpixels_per_pixel);
        const dy = @divFloor(pos.y, levels.subpixels_per_pixel) + hud_height;
        const dw = levels.pixels_per_tile;
        const dh = levels.pixels_per_tile;
        pdraw.tile(
            &g.draw_state,
            g.tileset,
            getGraphicTile(graphic),
            dx, dy, dw, dh,
            .Identity,
        );
    }
}

fn drawMap(g: *GameState) void {
    //perf.begin(&perf.timers.DrawMap);
    //defer perf.end(&perf.timers.DrawMap, g.perf_spam);

    var y: u31 = 0; while (y < levels.height) : (y += 1) {
        var x: u31 = 0; while (x < levels.width) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

// make the central 2x2 map tiles a foreground layer, so that the player spawn
// anim makes him arise from behind it. (this should probably be implemented as
// a regular entity later.)
fn drawMapForeground(g: *GameState) void {
    //perf.begin(&perf.timers.DrawMapForeground);
    //defer perf.end(&perf.timers.DrawMapForeground, g.perf_spam);

    var y: u31 = 6; while (y < 8) : (y += 1) {
        var x: u31 = 9; while (x < 11) : (x += 1) {
            drawMapTile(g, x, y);
        }
    }
}

fn drawEntities(g: *GameState, sorted_drawables: []*const c.EventDraw) void {
    //perf.begin(&perf.timers.DrawEntities);
    //defer perf.end(&perf.timers.DrawEntities, g.perf_spam);

    for (sorted_drawables) |drawable| {
        const x = @divFloor(drawable.pos.x, levels.subpixels_per_pixel);
        const y = @divFloor(drawable.pos.y, levels.subpixels_per_pixel) + hud_height;
        const w = levels.pixels_per_tile;
        const h = levels.pixels_per_tile;
        pdraw.tile(
            &g.draw_state,
            g.tileset,
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
            const x0 = @divFloor(abs_bbox.mins.x, levels.subpixels_per_pixel);
            const y0 = @divFloor(abs_bbox.mins.y, levels.subpixels_per_pixel) + hud_height;
            const x1 = @divFloor(abs_bbox.maxs.x + 1, levels.subpixels_per_pixel);
            const y1 = @divFloor(abs_bbox.maxs.y + 1, levels.subpixels_per_pixel) + hud_height;
            const w = x1 - x0;
            const h = y1 - y0;
            pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, object.data.color, 1.0, true);
            pdraw.tile(
                &g.draw_state,
                g.draw_state.blank_tileset,
                draw.Tile { .tx = 0, .ty = 0 },
                x0, y0, w, h,
                .Identity,
            );
            pdraw.end(&g.draw_state);
        }
    }
}

fn getColor(g: *GameState, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return draw.Color {
        .r = g.palette[index * 3 + 0],
        .g = g.palette[index * 3 + 1],
        .b = g.palette[index * 3 + 2],
    };
}

fn drawHud(g: *GameState, game_active: bool) void {
    //perf.begin(&perf.timers.DrawHud);
    //defer perf.end(&perf.timers.DrawHud, g.perf_spam);

    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);

    const mc = g.session.findFirst(c.MainController).?;
    const gc_maybe = g.session.findFirst(c.GameController);
    const pc_maybe = g.session.findFirst(c.PlayerController);

    pdraw.begin(&g.draw_state, g.draw_state.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        &g.draw_state,
        g.draw_state.blank_tileset,
        draw.Tile { .tx = 0, .ty = 0 },
        0, 0, @intToFloat(f32, vwin_w), @intToFloat(f32, hud_height),
        .Identity,
    );
    pdraw.end(&g.draw_state);

    const font_color = getColor(g, primary_font_color_index);
    pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);

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

            pdraw.end(&g.draw_state);
            const heart_font_color = getColor(g, heart_font_color_index);
            pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, heart_font_color, 1.0, false);
            var i: u31 = 0; while (i < pc.lives) : (i += 1) {
                fontDrawString(&g.draw_state, &g.font, (14+i)*8, 0, "\x1E"); // heart
            }
            pdraw.end(&g.draw_state);

            if (pc.lives == 0) {
                const skull_font_color = getColor(g, skull_font_color_index);
                pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, skull_font_color, 1.0, false);
                fontDrawString(&g.draw_state, &g.font, 14*8, 0, "\x1F"); // skull
                pdraw.end(&g.draw_state);
            }

            pdraw.begin(&g.draw_state, g.font.tileset.texture.handle, font_color, 1.0, false);

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

    _ = dest.stream.print("High:{}", mc.high_scores[0]) catch unreachable; // FIXME
    fontDrawString(&g.draw_state, &g.font, 30*8, 0, dest.getWritten());
    dest.reset();

    pdraw.end(&g.draw_state);

    if (if (gc_maybe) |gc| gc.game_over else false) {
        drawGameOverOverlay(g, mc.new_high_score);
    }
}
