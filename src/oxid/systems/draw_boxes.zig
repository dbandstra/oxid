const drawing = @import("../../common/drawing.zig");
const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

// draw boxes (diagnostic feature toggled by hitting F2).
pub fn run(gs: *game.Session) void {
    // since this is a debug feature it's not important to use the game's
    // 16-color palette (which doesn't have pure black).
    const black = drawing.pure_black;

    // draw a box around each PhysObject. color the box according to the
    // collision interaction group (two objects that are interacting should
    // have the same color).
    {
        var it = gs.ecs.componentIter(c.PhysObject);
        while (it.next()) |self_phys| {
            const int = self_phys.internal;
            p.spawnEventDrawBox(gs, .{
                .box = int.move_bbox,
                .color = .{
                    .r = @intCast(u8, 64 + ((int.group_index * 41) % 192)),
                    .g = @intCast(u8, 64 + ((int.group_index * 901) % 192)),
                    .b = @intCast(u8, 64 + ((int.group_index * 10031) % 192)),
                },
            });
        }
    }
    // draw a box representing the player's projected "line of fire" (which is
    // used by monster AI).
    {
        var it = gs.ecs.componentIter(c.Player);
        while (it.next()) |self_player| {
            const box = self_player.line_of_fire orelse continue;
            p.spawnEventDrawBox(gs, .{ .box = box, .color = black });
        }
    }
    // draw a box representing "line of fire" of bullets (also used by monster
    // AI).
    {
        var it = gs.ecs.componentIter(c.Bullet);
        while (it.next()) |self_bullet| {
            const box = self_bullet.line_of_fire orelse continue;
            p.spawnEventDrawBox(gs, .{ .box = box, .color = black });
        }
    }
}
