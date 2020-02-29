const std = @import("std");
const pdraw = @import("pdraw");
const math = @import("../common/math.zig");
const draw = @import("../common/draw.zig");
const fontDrawString = @import("../common/font.zig").fontDrawString;
const common = @import("../oxid_common.zig");
const ECS = @import("game.zig").ECS;
const GameSession = @import("game.zig").GameSession;
const Graphic = @import("graphics.zig").Graphic;
const getGraphicTile = @import("graphics.zig").getGraphicTile;
const levels = @import("levels.zig");
const config = @import("config.zig");
const c = @import("components.zig");
const perf = @import("perf.zig");
const util = @import("util.zig");
const drawGameOverOverlay = @import("draw_menu.zig").drawGameOverOverlay;

const primary_font_color_index = 15; // near-white
const heart_font_color_index = 6; // red
const skull_font_color_index = 10; // light grey

pub fn drawGame(
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    gs: *GameSession,
    cfg: config.Config,
    high_score: u32,
) void {
    const mc = gs.ecs.findFirstComponent(c.MainController) orelse return;

    if (mc.game_running_state) |grs| {
        const max_drawables = comptime ECS.getCapacity(c.EventDraw);
        var sort_buffer: [max_drawables]*const c.EventDraw = undefined;
        const sorted_drawables = getSortedDrawables(gs, sort_buffer[0..]);

        pdraw.begin(ds, static.tileset.texture.handle, null, 1.0, false);
        drawMap(ds, static);
        drawEntities(ds, static, sorted_drawables);
        drawMapForeground(ds, static);
        pdraw.end(ds);

        drawBoxes(ds, gs);
        drawHud(ds, static, gs, high_score);
    } else {
        pdraw.begin(ds, static.tileset.texture.handle, null, 1.0, false);
        drawMap(ds, static);
        pdraw.end(ds);

        drawHud(ds, static, gs, high_score);
    }
}

///////////////////////////////////////

fn getSortedDrawables(
    gs: *GameSession,
    sort_buffer: []*const c.EventDraw,
) []*const c.EventDraw {
    perf.begin(.draw_sort);
    defer perf.end(.draw_sort);

    var num_drawables: usize = 0;
    var it = gs.ecs.componentIter(c.EventDraw); while (it.next()) |event| {
        sort_buffer[num_drawables] = event;
        num_drawables += 1;
    }
    var sorted_drawables = sort_buffer[0..num_drawables];
    std.sort.sort(
        *const c.EventDraw,
        sorted_drawables,
        util.lessThanField(*const c.EventDraw, "z_index"),
    );
    return sorted_drawables;
}

fn drawMapTile(
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    x: u31,
    y: u31,
) void {
    const gridpos = math.Vec2.init(x, y);
    if (switch (levels.level1.getGridValue(gridpos).?) {
        0x00 => Graphic.floor,
        0x80 => Graphic.wall,
        0x81 => Graphic.wall2,
        0x82 => Graphic.pit,
        0x83 => Graphic.evilwall_tl,
        0x84 => Graphic.evilwall_tr,
        0x85 => Graphic.evilwall_bl,
        0x86 => Graphic.evilwall_br,
        else => null,
    }) |graphic| {
        const pos = math.Vec2.scale(gridpos, levels.subpixels_per_tile);
        const dx = @divFloor(pos.x, levels.subpixels_per_pixel);
        const dy = @divFloor(pos.y, levels.subpixels_per_pixel) + common.hud_height;
        const dw = levels.pixels_per_tile;
        const dh = levels.pixels_per_tile;
        pdraw.tile(
            ds,
            static.tileset,
            getGraphicTile(graphic),
            dx, dy, dw, dh,
            .identity,
        );
    }
}

fn drawMap(ds: *pdraw.DrawState, static: *const common.GameStatic) void {
    perf.begin(.draw_map);
    defer perf.end(.draw_map);

    var y: u31 = 0; while (y < levels.height) : (y += 1) {
        var x: u31 = 0; while (x < levels.width) : (x += 1) {
            drawMapTile(ds, static, x, y);
        }
    }
}

// make the central 2x2 map tiles a foreground layer, so that the player spawn
// anim makes him arise from behind it. (this should probably be implemented as
// a regular entity later.)
fn drawMapForeground(ds: *pdraw.DrawState, static: *const common.GameStatic) void {
    perf.begin(.draw_map_foreground);
    defer perf.end(.draw_map_foreground);

    var y: u31 = 6; while (y < 8) : (y += 1) {
        var x: u31 = 9; while (x < 11) : (x += 1) {
            drawMapTile(ds, static, x, y);
        }
    }
}

fn drawEntities(
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    sorted_drawables: []*const c.EventDraw,
) void {
    perf.begin(.draw_entities);
    defer perf.end(.draw_entities);

    for (sorted_drawables) |drawable| {
        const x = @divFloor(drawable.pos.x, levels.subpixels_per_pixel);
        const y = @divFloor(drawable.pos.y, levels.subpixels_per_pixel) + common.hud_height;
        const w = levels.pixels_per_tile;
        const h = levels.pixels_per_tile;
        pdraw.tile(
            ds,
            static.tileset,
            getGraphicTile(drawable.graphic),
            x, y, w, h,
            drawable.transform,
        );
    }
}

fn drawBoxes(ds: *pdraw.DrawState, gs: *GameSession) void {
    var it = gs.ecs.componentIter(c.EventDrawBox); while (it.next()) |event| {
        const abs_bbox = event.box;
        const x0 = @divFloor(abs_bbox.mins.x, levels.subpixels_per_pixel);
        const y0 = @divFloor(abs_bbox.mins.y, levels.subpixels_per_pixel) + common.hud_height;
        const x1 = @divFloor(abs_bbox.maxs.x + 1, levels.subpixels_per_pixel);
        const y1 = @divFloor(abs_bbox.maxs.y + 1, levels.subpixels_per_pixel) + common.hud_height;
        const w = x1 - x0;
        const h = y1 - y0;
        pdraw.begin(ds, ds.blank_tex.handle, event.color, 1.0, true);
        pdraw.tile(
            ds,
            ds.blank_tileset,
            .{ .tx = 0, .ty = 0 },
            x0, y0, w, h,
            .identity,
        );
        pdraw.end(ds);
    }
}

fn getColor(static: *const common.GameStatic, index: usize) draw.Color {
    std.debug.assert(index < 16);

    return .{
        .r = static.palette[index * 3 + 0],
        .g = static.palette[index * 3 + 1],
        .b = static.palette[index * 3 + 2],
    };
}

fn drawHud(
    ds: *pdraw.DrawState,
    static: *const common.GameStatic,
    gs: *GameSession,
    high_score: u32,
) void {
    perf.begin(.draw_hud);
    defer perf.end(.draw_hud);

    var buffer: [40]u8 = undefined;
    var dest = std.io.SliceOutStream.init(buffer[0..]);

    const mc = gs.ecs.findFirstComponent(c.MainController).?;
    const gc_maybe = gs.ecs.findFirstComponent(c.GameController);

    pdraw.begin(ds, ds.blank_tex.handle, draw.black, 1.0, false);
    pdraw.tile(
        ds,
        ds.blank_tileset,
        .{ .tx = 0, .ty = 0 },
        0,
        0,
        @intToFloat(f32, common.virtual_window_width),
        @intToFloat(f32, common.hud_height),
        .identity,
    );
    pdraw.end(ds);

    const font_color = getColor(static, primary_font_color_index);
    pdraw.begin(ds, static.font.tileset.texture.handle, font_color, 1.0, false);

    if (gc_maybe) |gc| {
        _ = dest.stream.print("Wave:{}", .{gc.wave_number}) catch unreachable; // FIXME
        fontDrawString(ds, &static.font, 0, 0, dest.getWritten());
        dest.reset();

        var player_number: u31 = 0; while (player_number < 2) : (player_number += 1) {
            const pc_maybe = blk: {
                var it = gs.ecs.componentIter(c.PlayerController);
                while (it.next()) |pc| {
                    if (pc.player_number == player_number) {
                        break :blk pc;
                    }
                }
                break :blk null;
            };

            if (pc_maybe) |pc| {
                const y = player_number * 8;

                if (player_number == 1) {
                    // multiplayer game: show little colored helmets in the HUD
                    // to make it clear which player is which
                    pdraw.end(ds);
                    pdraw.begin(ds, static.tileset.texture.handle, null, 1.0, false);
                    pdraw.tile(
                        ds,
                        static.tileset,
                        getGraphicTile(.man_icons),
                        6*8-2, -1, 16, 16,
                        .identity,
                    );
                    pdraw.end(ds);
                    pdraw.begin(ds, static.font.tileset.texture.handle, font_color, 1.0, false);
                }

                const maybe_player_creature =
                    if (pc.player_id) |player_id|
                        gs.ecs.findComponentById(player_id, c.Creature)
                    else
                        null;

                if (if (maybe_player_creature) |creature| creature.god_mode else false) {
                    fontDrawString(ds, &static.font, 8*8, y, "(god):");
                } else {
                    fontDrawString(ds, &static.font, 8*8, y, "Lives:");
                }
                pdraw.end(ds);

                const heart_font_color = getColor(static, heart_font_color_index);
                pdraw.begin(ds, static.font.tileset.texture.handle, heart_font_color, 1.0, false);
                var i: u31 = 0; while (i < pc.lives) : (i += 1) {
                    fontDrawString(ds, &static.font, (14+i)*8, y, "\x1E"); // heart
                }
                pdraw.end(ds);

                if (pc.lives == 0) {
                    const skull_font_color = getColor(static, skull_font_color_index);
                    pdraw.begin(ds, static.font.tileset.texture.handle, skull_font_color, 1.0, false);
                    fontDrawString(ds, &static.font, 14*8, y, "\x1F"); // skull
                    pdraw.end(ds);
                }

                pdraw.begin(ds, static.font.tileset.texture.handle, font_color, 1.0, false);
                _ = dest.stream.print("Score:{}", .{pc.score}) catch unreachable; // FIXME
                fontDrawString(ds, &static.font, 19*8, y, dest.getWritten());
                dest.reset();
            }
        }

        if (gc.wave_message) |message| {
            if (gc.wave_message_timer > 0) {
                const x = common.virtual_window_width / 2 - message.len * 8 / 2;
                fontDrawString(ds, &static.font, @intCast(i32, x), 28*8, message);
            }
        }
    }

    _ = dest.stream.print("High:{}", .{high_score}) catch unreachable; // FIXME
    fontDrawString(ds, &static.font, 30*8, 0, dest.getWritten());
    dest.reset();

    pdraw.end(ds);
}
