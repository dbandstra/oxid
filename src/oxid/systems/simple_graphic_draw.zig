const game = @import("../game.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");
const util = @import("../util.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        transform: *const c.Transform,
        phys: ?*const c.PhysObject,
        simple_graphic: *const c.SimpleGraphic,
    });
    while (it.next()) |self| {
        p.spawnEventDraw(gs, .{
            .pos = self.transform.pos,
            .graphic = self.simple_graphic.graphic,
            .transform = if (self.simple_graphic.directional)
                if (self.phys) |phys|
                    util.getDirTransform(phys.facing)
                else
                    .identity
            else
                .identity,
            .z_index = self.simple_graphic.z_index,
        });
    }
}
