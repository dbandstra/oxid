const gbe = @import("gbe");
const GameSession = @import("../game.zig").GameSession;
const c = @import("../components.zig");
const p = @import("../prototypes.zig");

const SystemData = struct {
    id: gbe.EntityId,
    pickup: *const c.Pickup,
};

pub const run = gbe.buildSystem(GameSession, SystemData, collide);

fn collide(gs: *GameSession, self: SystemData) gbe.ThinkResult {
    var it = gs.eventIter(c.EventCollide, "self_id", self.id); while (it.next()) |event| {
        const other_player = gs.find(event.other_id, c.Player) orelse continue;
        _ = p.EventConferBonus.spawn(gs, c.EventConferBonus {
            .recipient_id = event.other_id,
            .pickup_type = self.pickup.pickup_type,
        }) catch undefined;
        _ = p.EventAwardPoints.spawn(gs, c.EventAwardPoints {
            .player_controller_id = other_player.player_controller_id,
            .points = self.pickup.get_points,
        }) catch undefined;
        if (self.pickup.message) |message| {
            _ = p.EventShowMessage.spawn(gs, c.EventShowMessage {
                .message = message,
            }) catch undefined;
        }
        return .RemoveSelf;
    }
    return .Remain;
}
