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
            .attack = .Instantaneous,
            .decay = .Instantaneous,
            .release = zang.Envelope.Curve { .Linear = 0.04 },
            .sustain_volume = 1.0,
            .note_on = params.note_on,
        });
        zang.multiplyWithScalar(span, temps[1], 0.25);
        zang.multiply(span, outputs[0], temps[0], temps[1]);
    }
};

pub const MenuDingVoice = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        unused: u32,
    };
    pub const NoteParams = struct {
        // compiler was segfaulting when this was empty (2019-07-29)
        unused: u32,
    };

    pub const sound_duration = 2.0;

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,
    flt: zang.Filter,

    pub fn init() MenuDingVoice {
        const SongEvent = zang.Notes(Instrument.NoteParams).SongEvent;
        const IParams = Instrument.NoteParams;
        const f = 1.25;

        return MenuDingVoice {
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = zang.Notes(Instrument.NoteParams).NoteTracker.init([_]SongEvent {
                SongEvent { .params = IParams { .freq = 80.0, .note_on = true }, .note_id = 1, .t = f * 0.0 },
                SongEvent { .params = IParams { .freq = 60.0, .note_on = true }, .note_id = 2, .t = f * 0.01 },
                SongEvent { .params = IParams { .freq = 70.0, .note_on = true }, .note_id = 3, .t = f * 0.02 },
                SongEvent { .params = IParams { .freq = 50.0, .note_on = true }, .note_id = 4, .t = f * 0.03 },
                SongEvent { .params = IParams { .freq = 60.0, .note_on = true }, .note_id = 5, .t = f * 0.04 },
                SongEvent { .params = IParams { .freq = 40.0, .note_on = true }, .note_id = 6, .t = f * 0.05 },
                SongEvent { .params = IParams { .freq = 50.0, .note_on = true }, .note_id = 7, .t = f * 0.06 },
                SongEvent { .params = IParams { .freq = 30.0, .note_on = true }, .note_id = 8, .t = f * 0.07 },
                SongEvent { .params = IParams { .freq = 40.0, .note_on = true }, .note_id = 9, .t = f * 0.08 },
                SongEvent { .params = IParams { .freq = 20.0, .note_on = true }, .note_id = 10, .t = f * 0.09 },
                SongEvent { .params = IParams { .freq = 30.0, .note_on = false }, .note_id = 11, .t = f * 0.1 },
            }),
            .flt = zang.Filter.init(),
        };
    }

    pub fn paint(self: *MenuDingVoice, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.trigger.reset();
            self.note_tracker.reset();
        }

        zang.zero(span, temps[2]);

        var ctr = self.trigger.counter(span, self.note_tracker.consume(params.sample_rate, span.end - span.start));
        while (self.trigger.next(&ctr)) |result| {
            self.instrument.paint(result.span, [1][]f32{temps[2]}, [2][]f32{temps[0], temps[1]}, note_id_changed or result.note_id_changed, Instrument.Params {
                .sample_rate = params.sample_rate,
                .freq = result.params.freq,
                .note_on = result.params.note_on,
            });
        }

        self.flt.paint(span, outputs, [0][]f32{}, zang.Filter.Params {
            .input = temps[2],
            .filter_type = .LowPass,
            .cutoff = zang.constant(zang.cutoffFromFrequency(2000.0, params.sample_rate)),
            .resonance = 0.3,
        });
    }
};
