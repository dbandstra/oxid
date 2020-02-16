const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        phys: *const c.PhysObject,
    });

    while (it.next()) |self| {
        const int = self.phys.internal;

        _ = p.EventDrawBox.spawn(gs, .{
            .box = int.move_bbox,
            .color = .{
                .r = @intCast(u8, 64 + ((int.group_index * 41) % 192)),
                .g = @intCast(u8, 64 + ((int.group_index * 901) % 192)),
                .b = @intCast(u8, 64 + ((int.group_index * 10031) % 192)),
            },
        }) catch undefined;
    }
}
