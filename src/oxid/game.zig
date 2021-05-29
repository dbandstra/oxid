const std = @import("std");
const gbe = @import("gbe");
const physics = @import("physics.zig");
const c = @import("components.zig");
const p = @import("prototypes.zig");

pub const ComponentLists = struct {
    Animation: gbe.ComponentList(c.Animation, 10),
    Bullet: gbe.ComponentList(c.Bullet, 10),
    Creature: gbe.ComponentList(c.Creature, 100),
    GameController: gbe.ComponentList(c.GameController, 1),
    Monster: gbe.ComponentList(c.Monster, 50),
    PhysObject: gbe.ComponentList(c.PhysObject, 100),
    Pickup: gbe.ComponentList(c.Pickup, 10),
    Player: gbe.ComponentList(c.Player, 50),
    PlayerController: gbe.ComponentList(c.PlayerController, 2),
    RemoveTimer: gbe.ComponentList(c.RemoveTimer, 50),
    SimpleGraphic: gbe.ComponentList(c.SimpleGraphic, 50),
    Transform: gbe.ComponentList(c.Transform, 100),
    VoiceAccelerate: gbe.ComponentList(c.VoiceAccelerate, 1),
    VoiceCoin: gbe.ComponentList(c.VoiceCoin, 50),
    VoiceDropWeb: gbe.ComponentList(c.VoiceDropWeb, 50),
    VoiceExplosion: gbe.ComponentList(c.VoiceExplosion, 10),
    VoiceLaser: gbe.ComponentList(c.VoiceLaser, 100),
    VoicePowerUp: gbe.ComponentList(c.VoicePowerUp, 100),
    VoiceSampler: gbe.ComponentList(c.VoiceSampler, 100),
    VoiceWaveBegin: gbe.ComponentList(c.VoiceWaveBegin, 1),
    Web: gbe.ComponentList(c.Web, 100),
    EventAwardLife: gbe.ComponentList(c.EventAwardLife, 20),
    EventAwardPoints: gbe.ComponentList(c.EventAwardPoints, 20),
    EventCollide: gbe.ComponentList(c.EventCollide, 50),
    EventConferBonus: gbe.ComponentList(c.EventConferBonus, 5),
    EventDraw: gbe.ComponentList(c.EventDraw, 100),
    EventDrawBox: gbe.ComponentList(c.EventDrawBox, 100),
    EventGameInput: gbe.ComponentList(c.EventGameInput, 20),
    EventGameOver: gbe.ComponentList(c.EventGameOver, 20),
    EventMonsterDied: gbe.ComponentList(c.EventMonsterDied, 20),
    EventPlayerDied: gbe.ComponentList(c.EventPlayerDied, 20),
    EventShowMessage: gbe.ComponentList(c.EventShowMessage, 5),
    EventTakeDamage: gbe.ComponentList(c.EventTakeDamage, 20),
};

pub const ECS = gbe.ECS(ComponentLists);

pub const Session = struct {
    ecs: ECS,
    prng: std.rand.DefaultPrng,
    render_move_boxes: bool,
    game_controller_id: gbe.EntityId,
};

pub fn init(gs: *Session, random_seed: u32, is_multiplayer: bool) void {
    gs.ecs.init();
    gs.prng = std.rand.DefaultPrng.init(random_seed);

    const player1_controller_id =
        p.spawnPlayerController(gs, .{ .color = .yellow }).?;
    const player2_controller_id = if (is_multiplayer)
        p.spawnPlayerController(gs, .{ .color = .green })
    else
        null;

    const game_controller_id = p.spawnGameController(gs, .{
        .player1_controller_id = player1_controller_id,
        .player2_controller_id = player2_controller_id,
    }).?;

    gs.render_move_boxes = false;
    gs.game_controller_id = game_controller_id;
}

pub const FrameContext = struct {
    spawn_draw_events: bool,
    friendly_fire: bool,
};

fn runSystem(gs: *Session, context: FrameContext, comptime name: []const u8) void {
    const func = @import("systems/" ++ name ++ ".zig").run;

    if (@typeInfo(@TypeOf(func)).Fn.args.len == 2) {
        func(gs, context);
    } else {
        func(gs);
    }
}

// run before "middleware" (rendering, sound, etc)
pub fn frame(gs: *Session, ctx: FrameContext, paused: bool) void {
    runSystem(gs, ctx, "input");

    if (!paused) {
        runSystem(gs, ctx, "game_controller");
        runSystem(gs, ctx, "player_controller");
        runSystem(gs, ctx, "animation");
        runSystem(gs, ctx, "player_movement");
        runSystem(gs, ctx, "monster_movement");
        runSystem(gs, ctx, "bullet");
        runSystem(gs, ctx, "creature");
        runSystem(gs, ctx, "remove_timer");

        physics.frame(gs);

        // pickups react to event_collide, spawn event_confer_bonus
        runSystem(gs, ctx, "pickup_collide");
        // bullets react to event_collide, spawn event_take_damage
        runSystem(gs, ctx, "bullet_collide");
        // monsters react to event_collide, damage others
        runSystem(gs, ctx, "monster_touch_response");
        // player reacts to event_confer_bonus, gets bonus effect
        runSystem(gs, ctx, "player_reaction");

        // creatures react to event_take_damage, die
        runSystem(gs, ctx, "creature_take_damage");

        // player controller reacts to 'player died' event
        runSystem(gs, ctx, "player_controller_react");
        // game controller reacts to 'player died' event
        runSystem(gs, ctx, "game_controller_react");
    }

    gs.ecs.applyRemovals();

    if (ctx.spawn_draw_events) {
        // send draw commands (as events)
        runSystem(gs, ctx, "draw");

        if (gs.render_move_boxes) {
            runSystem(gs, ctx, "draw_boxes");
        }
    }
}

// run after "middleware" (rendering, sound, etc)
pub fn frameCleanup(gs: *Session) void {
    // mark all events for removal
    inline for (@typeInfo(ComponentLists).Struct.fields) |field| {
        const ComponentType = field.field_type.ComponentType;
        if (comptime std.mem.startsWith(u8, @typeName(ComponentType), "Event")) {
            gs.ecs.markAllForRemoval(ComponentType);
        }
    }

    gs.ecs.applyRemovals();
}
