const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

pub fn run(gs: *GameSession) void {
    var it = gs.eventIter(c.EventCollide, "self_id", struct {
        id: gbe.EntityId,
        pickup: *const c.Pickup,
    });

    while (it.next()) |entry| {
        const self = entry.subject;
        const event = entry.event;

        if (gs.isMarkedForRemoval(self.id)) {
            continue;
        }

        const other_player = gs.find(event.other_id, c.Player) orelse continue;

        _ = p.EventConferBonus.spawn(gs, .{
            .recipient_id = event.other_id,
            .pickup_type = self.pickup.pickup_type,
        }) catch undefined;

        _ = p.EventAwardPoints.spawn(gs, .{
            .player_controller_id = other_player.player_controller_id,
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
