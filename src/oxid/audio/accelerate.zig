const zang = @import("zang");

const Instrument = @import("wave_begin.zig").Instrument;

pub const AccelerateVoice = struct {
    pub const NumOutputs = 1;
    pub const NumTemps = 2;
    pub const Params = struct {
        sample_rate: f32,
        playback_speed: f32,
    };
    pub const NoteParams = struct {
        playback_speed: f32,
    };

    pub const SoundDuration = 2.0;

    instrument: Instrument,
    trigger: zang.Trigger(Instrument.NoteParams),
    note_tracker: zang.Notes(Instrument.NoteParams).NoteTracker,

    pub fn init() AccelerateVoice {
        const SongNote = zang.Notes(Instrument.NoteParams).SongNote;
        const speed = 0.125;

        return AccelerateVoice {
            .instrument = Instrument.init(),
            .trigger = zang.Trigger(Instrument.NoteParams).init(),
            .note_tracker = zang.Notes(Instrument.NoteParams).NoteTracker.init([]SongNote {
                // same as wave_begin but with some notes chopped off
                SongNote { .params = Instrument.NoteParams { .freq = 43.0, .note_on = true }, .t = 0.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 36.0, .note_on = true }, .t = 1.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 40.0, .note_on = true }, .t = 2.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 45.0, .note_on = true }, .t = 3.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 43.0, .note_on = true }, .t = 4.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 35.0, .note_on = true }, .t = 5.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 38.0, .note_on = true }, .t = 6.0 * speed },
                SongNote { .params = Instrument.NoteParams { .freq = 38.0, .note_on = false }, .t = 7.0 * speed },
            }),
        };
    }

    pub fn paint(self: *AccelerateVoice, span: zang.Span, outputs: [NumOutputs][]f32, temps: [NumTemps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.trigger.reset();
            self.note_tracker.reset();
        }

        var ctr = self.trigger.counter(span, self.note_tracker.consume(params.sample_rate / params.playback_speed, span.end - span.start));
        while (self.trigger.next(&ctr)) |result| {
            self.instrument.paint(result.span, outputs, temps, note_id_changed or result.note_id_changed, Instrument.Params {
                .sample_rate = params.sample_rate,
                .freq = result.params.freq * params.playback_speed,
                .note_on = result.params.note_on,
            });
        }
    }
};
