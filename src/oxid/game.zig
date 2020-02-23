const std = @import("std");
const gbe = @import("gbe");
const c = @import("components.zig");

pub const component_defs = [_]gbe.ComponentDef {
    .{ .Type = c.Animation, .capacity = 10 },
    .{ .Type = c.Bullet, .capacity = 10 },
    .{ .Type = c.Creature, .capacity = 100 },
    .{ .Type = c.GameController, .capacity = 2 },
    .{ .Type = c.MainController, .capacity = 1 },
    .{ .Type = c.Monster, .capacity = 50 },
    .{ .Type = c.PhysObject, .capacity = 100 },
    .{ .Type = c.Pickup, .capacity = 10 },
    .{ .Type = c.Player, .capacity = 50 },
    .{ .Type = c.PlayerController, .capacity = 4 },
    .{ .Type = c.RemoveTimer, .capacity = 50 },
    .{ .Type = c.SimpleGraphic, .capacity = 50 },
    .{ .Type = c.Transform, .capacity = 100 },
    .{ .Type = c.Voice, .capacity = 100 },
    .{ .Type = c.Web, .capacity = 100 },
    .{ .Type = c.EventAwardLife, .capacity = 20 },
    .{ .Type = c.EventAwardPoints, .capacity = 20 },
    .{ .Type = c.EventCollide, .capacity = 50 },
    .{ .Type = c.EventConferBonus, .capacity = 5 },
    .{ .Type = c.EventDraw, .capacity = 100 },
    .{ .Type = c.EventDrawBox, .capacity = 100 },
    .{ .Type = c.EventGameInput, .capacity = 20 },
    .{ .Type = c.EventGameOver, .capacity = 20 },
    .{ .Type = c.EventMonsterDied, .capacity = 20 },
    .{ .Type = c.EventPlayerDied, .capacity = 20 },
    .{ .Type = c.EventPlayerOutOfLives, .capacity = 20 },
    .{ .Type = c.EventShowMessage, .capacity = 5 },
    .{ .Type = c.EventTakeDamage, .capacity = 20 },
};

pub const ECS = gbe.ECS(&component_defs);

pub const GameSession = struct {
    ecs: ECS,
    prng: std.rand.DefaultPrng,

    pub fn init(
        self: *GameSession,
        allocator: *std.mem.Allocator,
        rand_seed: u32,
    ) !void {
        try self.ecs.init(allocator);
        self.prng = std.rand.DefaultPrng.init(rand_seed);
    }

    pub fn deinit(self: *GameSession, allocator: *std.mem.Allocator) void {
        self.ecs.deinit(allocator);
    }

    pub fn getRand(self: *GameSession) *std.rand.Random {
        return &self.prng.random;
    }
};
