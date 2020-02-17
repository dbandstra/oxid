const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.entityIter(struct {
        id: gbe.EntityId,
        pickup: *const c.Pickup,
        inbox_collide: gbe.Inbox(1, c.EventCollide, "self_id"),
    });

    while (it.next()) |self| {
        const event = self.inbox_collide.one orelse continue;

        const player = gs.find(event.other_id, c.Player) orelse continue;

        _ = p.EventConferBonus.spawn(gs, .{
            .recipient_id = event.other_id,
            .pickup_type = self.pickup.pickup_type,
        }) catch undefined;

        _ = p.EventAwardPoints.spawn(gs, .{
            .player_controller_id = player.player_controller_id,
            .points = self.pickup.get_points,
        }) catch undefined;

        if (self.pickup.message) |message| {
            _ = p.EventShowMessage.spawn(gs, .{
                .message = message,
            }) catch undefined;
        }

        gs.markEntityForRemoval(self.id);
    }
}
