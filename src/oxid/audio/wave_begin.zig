const zang = @import("zang");

pub const Instrument = struct {
    pub const num_outputs = 1;
    pub const num_temps = 2;
    pub const Params = struct { sample_rate: f32, freq: f32, note_on: bool };
    pub const NoteParams = struct { freq: f32, note_on: bool };

    osc: zang.PulseOsc,
    env: zang.Envelope,

    pub fn init() Instrument {
        return .{
            .osc = zang.PulseOsc.init(),
            .env = zang.Envelope.init(),
        };
    }

    pub fn paint(
        self: *Instrument,
        span: zang.Span,
        outputs: [num_outputs][]f32,
        temps: [num_temps][]f32,
        note_id_changed: bool,
        params: Params,
    ) void {
        zang.zero(span, temps[0]);
        self.osc.paint(span, .{temps[0]}, .{}, .{
            .sample_rate = params.sample_rate,
            .freq = zang.constant(params.freq),
            .color = 0.5,
        });
        zang.zero(span, temps[1]);
        self.env.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .attack = .{ .linear = 0.01 },
            .decay = .{ .linear = 0.1 },
            .release = .{ .linear = 0.15 },
            .sustain_volume = 0.5,
            .note_on = params.note_on,
        });
        zang.multiplyWithScalar(span, temps[1], 0.25);
        zang.multiply(span, outputs[0], temps[0], temps[1]);
    }
};

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

pub const WaveBeginVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 2;
    pub const Params = struct { sample_rate: f32 };
    pub const NoteParams = struct {};

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,

    pub fn init() WaveBeginVoice {
        const Notes = zang.Notes(Instrument.NoteParams);
        const IParams = Instrument.NoteParams;
        const speed = 0.125;

        return .{
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = Notes.NoteTracker.init(&[_]Notes.SongEvent{
                comptime makeNote(0.0 * speed, 1, 40.0, true),
                comptime makeNote(1.0 * speed, 2, 43.0, true),
                comptime makeNote(2.0 * speed, 3, 36.0, true),
                comptime makeNote(3.0 * speed, 4, 45.0, true),
                comptime makeNote(4.0 * speed, 5, 43.0, true),
                comptime makeNote(5.0 * speed, 6, 36.0, true),
                comptime makeNote(6.0 * speed, 7, 40.0, true),
                comptime makeNote(7.0 * speed, 8, 45.0, true),
                comptime makeNote(8.0 * speed, 9, 43.0, true),
                comptime makeNote(9.0 * speed, 10, 35.0, true),
                comptime makeNote(10.0 * speed, 11, 38.0, true),
                comptime makeNote(11.0 * speed, 12, 38.0, false),
            }),
        };
    }

    pub fn paint(
        self: *WaveBeginVoice,
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
                params.sample_rate,
                span.end - span.start,
            ),
        );
        while (self.trigger.next(&ctr)) |result| {
            const new_note = note_id_changed or result.note_id_changed;
            self.instrument.paint(result.span, outputs, temps, new_note, .{
                .sample_rate = params.sample_rate,
                .freq = result.params.freq,
                .note_on = result.params.note_on,
            });
        }
    }
};
