const zang = @import("zang");

pub const Instrument = struct {
    pub const num_outputs = 1;
    pub const num_temps = 2;
    pub const Params = struct { sample_rate: f32, freq: f32, note_on: bool };
    pub const NoteParams = struct { freq: f32, note_on: bool };

    osc: zang.PulseOsc,
    env: zang.Envelope,

    pub fn init() Instrument {
        return Instrument {
            .osc = zang.PulseOsc.init(),
            .env = zang.Envelope.init(),
        };
    }

    pub fn paint(self: *Instrument, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.osc.paint(span, [1][]f32{temps[0]}, [0][]f32{}, zang.PulseOsc.Params {
            .sample_rate = params.sample_rate,
            .freq = params.freq,
            .color = 0.5,
        });
        zang.zero(span, temps[1]);
        self.env.paint(span, [1][]f32{temps[1]}, [0][]f32{}, note_id_changed, zang.Envelope.Params {
            .sample_rate = params.sample_rate,
            .attack = zang.Envelope.Curve { .Linear = 0.01 },
            .decay = zang.Envelope.Curve { .Linear = 0.1 },
            .release = zang.Envelope.Curve { .Linear = 0.15 },
            .sustain_volume = 0.5,
            .note_on = params.note_on,
        });
        zang.multiplyWithScalar(span, temps[1], 0.25);
        zang.multiply(span, outputs[0], temps[0], temps[1]);
    }
};

pub const WaveBeginVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 2;
    pub const Params = struct { sample_rate: f32, unused: bool };
    pub const NoteParams = struct { unused: bool };

    pub const sound_duration = 2.0;

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,

    pub fn init() WaveBeginVoice {
        const SongEvent = zang.Notes(Instrument.NoteParams).SongEvent;
        const IParams = Instrument.NoteParams;
        const speed = 0.125;

        return WaveBeginVoice {
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = zang.Notes(Instrument.NoteParams).NoteTracker.init([_]SongEvent {
                SongEvent { .params = IParams { .freq = 40.0, .note_on = true }, .note_id = 1, .t = 0.0 * speed },
                SongEvent { .params = IParams { .freq = 43.0, .note_on = true }, .note_id = 2, .t = 1.0 * speed },
                SongEvent { .params = IParams { .freq = 36.0, .note_on = true }, .note_id = 3, .t = 2.0 * speed },
                SongEvent { .params = IParams { .freq = 45.0, .note_on = true }, .note_id = 4, .t = 3.0 * speed },
                SongEvent { .params = IParams { .freq = 43.0, .note_on = true }, .note_id = 5, .t = 4.0 * speed },
                SongEvent { .params = IParams { .freq = 36.0, .note_on = true }, .note_id = 6, .t = 5.0 * speed },
                SongEvent { .params = IParams { .freq = 40.0, .note_on = true }, .note_id = 7, .t = 6.0 * speed },
                SongEvent { .params = IParams { .freq = 45.0, .note_on = true }, .note_id = 8, .t = 7.0 * speed },
                SongEvent { .params = IParams { .freq = 43.0, .note_on = true }, .note_id = 9, .t = 8.0 * speed },
                SongEvent { .params = IParams { .freq = 35.0, .note_on = true }, .note_id = 10, .t = 9.0 * speed },
                SongEvent { .params = IParams { .freq = 38.0, .note_on = true }, .note_id = 11, .t = 10.0 * speed },
                SongEvent { .params = IParams { .freq = 38.0, .note_on = false }, .note_id = 12, .t = 11.0 * speed },
            }),
        };
    }

    pub fn paint(self: *WaveBeginVoice, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.trigger.reset();
            self.note_tracker.reset();
        }

        var ctr = self.trigger.counter(span, self.note_tracker.consume(params.sample_rate, span.end - span.start));
        while (self.trigger.next(&ctr)) |result| {
            self.instrument.paint(result.span, outputs, temps, note_id_changed or result.note_id_changed, Instrument.Params {
                .sample_rate = params.sample_rate,
                .freq = result.params.freq,
                .note_on = result.params.note_on,
            });
        }
    }
};
