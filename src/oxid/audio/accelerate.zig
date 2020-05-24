const zang = @import("zang");

const Instrument = @import("wave_begin.zig").Instrument;

fn makeNote(
    t: f32,
    note_id: usize,
    freq: f32,
    note_on: bool,
) zang.Notes(Instrument.NoteParams).SongEvent {
    return .{
        .t = t,
        .note_id = note_id,
        .params = .{ .freq = freq, .note_on = note_on },
    };
}

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
        const Notes = zang.Notes(Instrument.NoteParams);
        const IParams = Instrument.NoteParams;
        const speed = 0.125;

        return .{
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = Notes.NoteTracker.init(&[_]Notes.SongEvent{
                comptime makeNote(0.0 * speed, 1, 43.0, true),
                comptime makeNote(0.1 * speed, 2, 36.0, true),
                comptime makeNote(0.2 * speed, 3, 40.0, true),
                comptime makeNote(0.3 * speed, 4, 45.0, true),
                comptime makeNote(0.4 * speed, 5, 43.0, true),
                comptime makeNote(0.5 * speed, 6, 35.0, true),
                comptime makeNote(0.6 * speed, 7, 38.0, true),
                comptime makeNote(0.7 * speed, 8, 38.0, false),
            }),
        };
    }

    pub fn paint(
        self: *AccelerateVoice,
        span: zang.Span,
        outputs: [num_outputs][]f32,
        temps: [num_temps][]f32,
        note_id_changed: bool,
        params: Params,
    ) void {
        if (note_id_changed) {
            self.trigger.reset();
            self.note_tracker.reset();
        }
        var ctr = self.trigger.counter(
            span,
            self.note_tracker.consume(
                params.sample_rate / params.playback_speed,
                span.end - span.start,
            ),
        );
        while (self.trigger.next(&ctr)) |result| {
            const new_note = note_id_changed or result.note_id_changed;
            self.instrument.paint(result.span, outputs, temps, new_note, .{
                .sample_rate = params.sample_rate,
                .freq = result.params.freq * params.playback_speed,
                .note_on = result.params.note_on,
            });
        }
    }
};
