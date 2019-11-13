const zang = @import("zang");

const Instrument = @import("wave_begin.zig").Instrument;

pub const AccelerateVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 2;
    pub const Params = struct {
        sample_rate: f32,
        playback_speed: f32,
    };
    pub const NoteParams = struct {
        playback_speed: f32,
    };

    pub const sound_duration = 2.0;

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,

    pub fn init() AccelerateVoice {
        const SongEvent = zang.Notes(Instrument.NoteParams).SongEvent;
        const IParams = Instrument.NoteParams;
        const speed = 0.125;

        return .{
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = zang.Notes(Instrument.NoteParams).NoteTracker.init([_]SongEvent {
                // same as wave_begin but with some notes chopped off
       // https://github.com/ziglang/zig/issues/3679
       SongEvent { .params = .{ .freq = 43.0, .note_on = true }, .note_id = 1, .t = 0.0 * speed },
                .{ .params = .{ .freq = 36.0, .note_on = true }, .note_id = 2, .t = 1.0 * speed },
                .{ .params = .{ .freq = 40.0, .note_on = true }, .note_id = 3, .t = 2.0 * speed },
                .{ .params = .{ .freq = 45.0, .note_on = true }, .note_id = 4, .t = 3.0 * speed },
                .{ .params = .{ .freq = 43.0, .note_on = true }, .note_id = 5, .t = 4.0 * speed },
                .{ .params = .{ .freq = 35.0, .note_on = true }, .note_id = 6, .t = 5.0 * speed },
                .{ .params = .{ .freq = 38.0, .note_on = true }, .note_id = 7, .t = 6.0 * speed },
                .{ .params = .{ .freq = 38.0, .note_on = false }, .note_id = 8, .t = 7.0 * speed },
            }),
        };
    }

    pub fn paint(self: *AccelerateVoice, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.trigger.reset();
            self.note_tracker.reset();
        }

        var ctr = self.trigger.counter(span, self.note_tracker.consume(params.sample_rate / params.playback_speed, span.end - span.start));
        while (self.trigger.next(&ctr)) |result| {
            self.instrument.paint(result.span, outputs, temps, note_id_changed or result.note_id_changed, .{
                .sample_rate = params.sample_rate,
                .freq = result.params.freq * params.playback_speed,
                .note_on = result.params.note_on,
            });
        }
    }
};
