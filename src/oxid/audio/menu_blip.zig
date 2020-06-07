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
        self.osc.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.constant(params.freq),
            .color = 0.5,
        });
        zang.zero(span, temps[1]);
        self.env.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .attack = .instantaneous,
            .decay = .instantaneous,
            .release = .{ .linear = 0.04 },
            .sustain_volume = 1.0,
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

pub const MenuBlipVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
    };

    pub const sound_duration = 2.0;

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,
    flt: zang.Filter,

    pub fn init() MenuBlipVoice {
        const Notes = zang.Notes(Instrument.NoteParams);
        const IParams = Instrument.NoteParams;

        return .{
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = Notes.NoteTracker.init(&[_]Notes.SongEvent{
                comptime makeNote(0.00, 1, 60.0, true),
                comptime makeNote(0.02, 2, 60.0, false),
                comptime makeNote(0.08, 3, 40.0, true),
                comptime makeNote(0.10, 4, 40.0, false),
            }),
            .flt = zang.Filter.init(),
        };
    }

    pub fn paint(
        self: *MenuBlipVoice,
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

        zang.zero(span, temps[2]);

        var ctr = self.trigger.counter(
            span,
            self.note_tracker.consume(
                params.sample_rate,
                span.end - span.start,
            ),
        );
        while (self.trigger.next(&ctr)) |result| {
            self.instrument.paint(
                result.span,
                .{temps[2]},
                .{ temps[0], temps[1] },
                note_id_changed or result.note_id_changed,
                .{
                    .sample_rate = params.sample_rate,
                    .freq = result.params.freq * params.freq_mul,
                    .note_on = result.params.note_on,
                },
            );
        }

        self.flt.paint(span, outputs, .{}, note_id_changed, .{
            .input = temps[2],
            .type = .low_pass,
            .cutoff = zang.constant(zang.cutoffFromFrequency(
                2000.0 * params.freq_mul,
                params.sample_rate,
            )),
            .res = 0.3,
        });
    }
};
