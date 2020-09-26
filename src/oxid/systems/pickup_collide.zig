const gbe = @import("gbe");
const game = @import("../game.zig");
const constants = @import("../constants.zig");
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *game.Session) void {
    var it = gs.ecs.iter(struct {
        id: gbe.EntityId,
        pickup: *const c.Pickup,
        inbox: gbe.Inbox(1, c.EventCollide, "self_id"),
    });
    while (it.next()) |self| {
        const event = self.inbox.one();
        const other_player = gs.ecs.findComponentById(event.other_id, c.Player) orelse continue;

        p.eventConferBonus(gs, .{
            .recipient_id = event.other_id,
            .pickup_type = self.pickup.pickup_type,
        });

        p.eventAwardPoints(gs, .{
            .player_controller_id = other_player.player_controller_id,
            .points = constants.getPickupValues(self.pickup.pickup_type).get_points,
        });

        if (constants.getPickupValues(self.pickup.pickup_type).message) |message| {
            p.eventShowMessage(gs, .{
                .message = message,
            });
        }

        gs.ecs.markForRemoval(self.id);
    }
}
