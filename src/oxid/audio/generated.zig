// THIS FILE WAS GENERATED BY THE ZANGC COMPILER

const std = @import("std");
const zang = @import("zang");
const mod = @import("modules");

pub const MenuInstrument = _module12;
pub const MenuBlipVoice = _module13;
pub const MenuDingVoice = _module14;
pub const MenuBackoffVoice = _module15;
pub const WaveBeginInstrument = _module16;
pub const WaveBeginVoice = _module17;
pub const AccelerateVoice = _module18;
pub const CoinVoice = _module19;
pub const LaserVoice = _module20;
pub const ExplosionVoice = _module21;
pub const PowerUpVoice = _module22;
pub const DropWebVoice = _module23;

const _curve0 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 1000.0 },
    .{ .t = 0.1, .value = 200.0 },
    .{ .t = 0.2, .value = 100.0 },
};

const _curve1 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 0.0 },
    .{ .t = 0.004, .value = 0.35 },
    .{ .t = 0.2, .value = 0.0 },
};

const _curve2 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 3000.0 },
    .{ .t = 0.5, .value = 1000.0 },
    .{ .t = 0.7, .value = 200.0 },
};

const _curve3 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 0.0 },
    .{ .t = 0.004, .value = 0.75 },
    .{ .t = 0.7, .value = 0.0 },
};

const _curve4 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 360.0 },
    .{ .t = 0.109, .value = 1633.0 },
    .{ .t = 0.11, .value = 360.0 },
    .{ .t = 0.218, .value = 1633.0 },
    .{ .t = 0.219, .value = 360.0 },
    .{ .t = 0.327, .value = 1633.0 },
};

const _curve5 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 0.3 },
    .{ .t = 0.2, .value = 0.2 },
    .{ .t = 0.3, .value = 0.0 },
};

const _curve6 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 1.4 },
    .{ .t = 0.075, .value = 1.0 },
    .{ .t = 0.35, .value = 1.6 },
};

const _curve7 = [_]zang.CurveNode{
    .{ .t = 0.0, .value = 0.0 },
    .{ .t = 0.03, .value = 0.3 },
    .{ .t = 0.35, .value = 0.0 },
};

const _track0 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.00, .note_id = 1, .params = .{ .freq = 60.0, .note_on = true } },
        .{ .t = 0.02, .note_id = 2, .params = .{ .freq = 60.0, .note_on = false } },
        .{ .t = 0.08, .note_id = 3, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 0.10, .note_id = 4, .params = .{ .freq = 40.0, .note_on = false } },
    };
};

const _track1 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.00, .note_id = 1, .params = .{ .freq = 80.0, .note_on = true } },
        .{ .t = 0.01, .note_id = 2, .params = .{ .freq = 60.0, .note_on = true } },
        .{ .t = 0.02, .note_id = 3, .params = .{ .freq = 70.0, .note_on = true } },
        .{ .t = 0.03, .note_id = 4, .params = .{ .freq = 50.0, .note_on = true } },
        .{ .t = 0.04, .note_id = 5, .params = .{ .freq = 60.0, .note_on = true } },
        .{ .t = 0.05, .note_id = 6, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 0.06, .note_id = 7, .params = .{ .freq = 50.0, .note_on = true } },
        .{ .t = 0.07, .note_id = 8, .params = .{ .freq = 30.0, .note_on = true } },
        .{ .t = 0.08, .note_id = 9, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 0.09, .note_id = 10, .params = .{ .freq = 20.0, .note_on = true } },
        .{ .t = 0.10, .note_id = 11, .params = .{ .freq = 30.0, .note_on = false } },
    };
};

const _track2 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.00, .note_id = 1, .params = .{ .freq = 70.0, .note_on = true } },
        .{ .t = 0.01, .note_id = 2, .params = .{ .freq = 75.0, .note_on = true } },
        .{ .t = 0.02, .note_id = 3, .params = .{ .freq = 80.0, .note_on = true } },
        .{ .t = 0.03, .note_id = 4, .params = .{ .freq = 85.0, .note_on = true } },
        .{ .t = 0.04, .note_id = 5, .params = .{ .freq = 90.0, .note_on = true } },
        .{ .t = 0.05, .note_id = 6, .params = .{ .freq = 95.0, .note_on = true } },
        .{ .t = 0.06, .note_id = 7, .params = .{ .freq = 100.0, .note_on = true } },
        .{ .t = 0.07, .note_id = 8, .params = .{ .freq = 105.0, .note_on = false } },
    };
};

const _track3 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.0, .note_id = 1, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 1.0, .note_id = 2, .params = .{ .freq = 43.0, .note_on = true } },
        .{ .t = 2.0, .note_id = 3, .params = .{ .freq = 36.0, .note_on = true } },
        .{ .t = 3.0, .note_id = 4, .params = .{ .freq = 45.0, .note_on = true } },
        .{ .t = 4.0, .note_id = 5, .params = .{ .freq = 43.0, .note_on = true } },
        .{ .t = 5.0, .note_id = 6, .params = .{ .freq = 36.0, .note_on = true } },
        .{ .t = 6.0, .note_id = 7, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 7.0, .note_id = 8, .params = .{ .freq = 45.0, .note_on = true } },
        .{ .t = 8.0, .note_id = 9, .params = .{ .freq = 43.0, .note_on = true } },
        .{ .t = 9.0, .note_id = 10, .params = .{ .freq = 35.0, .note_on = true } },
        .{ .t = 10.0, .note_id = 11, .params = .{ .freq = 38.0, .note_on = true } },
        .{ .t = 11.0, .note_id = 12, .params = .{ .freq = 38.0, .note_on = false } },
    };
};

const _track4 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.0, .note_id = 1, .params = .{ .freq = 43.0, .note_on = true } },
        .{ .t = 1.0, .note_id = 2, .params = .{ .freq = 36.0, .note_on = true } },
        .{ .t = 2.0, .note_id = 3, .params = .{ .freq = 40.0, .note_on = true } },
        .{ .t = 3.0, .note_id = 4, .params = .{ .freq = 45.0, .note_on = true } },
        .{ .t = 4.0, .note_id = 5, .params = .{ .freq = 43.0, .note_on = true } },
        .{ .t = 5.0, .note_id = 6, .params = .{ .freq = 35.0, .note_on = true } },
        .{ .t = 6.0, .note_id = 7, .params = .{ .freq = 38.0, .note_on = true } },
        .{ .t = 7.0, .note_id = 8, .params = .{ .freq = 38.0, .note_on = false } },
    };
};

const _track5 = struct {
    const Params = struct {
        freq: f32,
        note_on: bool,
    };
    const notes = [_]zang.Notes(Params).SongEvent{
        .{ .t = 0.000, .note_id = 1, .params = .{ .freq = 750.0, .note_on = true } },
        .{ .t = 0.045, .note_id = 2, .params = .{ .freq = 1000.0, .note_on = true } },
        .{ .t = 0.090, .note_id = 3, .params = .{ .freq = 1000.0, .note_on = false } },
    };
};

const _module12 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq: f32,
        note_on: bool,
    };
    pub const NoteParams = struct {
        freq: f32,
        note_on: bool,
    };

    field0: mod.PulseOsc,
    field1: mod.Envelope,
    field2: mod.Filter,

    pub fn init() _module12 {
        return .{
            .field0 = mod.PulseOsc.init(),
            .field1 = mod.Envelope.init(),
            .field2 = mod.Filter.init(),
        };
    }

    pub fn paint(self: *_module12, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field0.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.constant(params.freq),
            .color = 0.5,
        });
        zang.zero(span, temps[1]);
        self.field1.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .attack = .instantaneous,
            .decay = .instantaneous,
            .release = .{ .linear = 0.04 },
            .sustain_volume = 1.0,
            .note_on = params.note_on,
        });
        zang.zero(span, temps[2]);
        zang.multiplyScalar(span, temps[2], temps[1], 0.25);
        zang.zero(span, temps[1]);
        zang.multiply(span, temps[1], temps[0], temps[2]);
        const temp_float0 = std.math.pi * 2000.0;
        const temp_float1 = temp_float0 / params.sample_rate;
        const temp_float2 = std.math.cos(temp_float1);
        const temp_float3 = 1.0 - temp_float2;
        const temp_float4 = 2.0 * temp_float3;
        const temp_float5 = std.math.min(1.0, temp_float4);
        const temp_float6 = std.math.max(0.0, temp_float5);
        const temp_float7 = std.math.sqrt(temp_float6);
        self.field2.paint(span, .{outputs[0]}, .{}, note_id_changed, .{
            .input = temps[1],
            .type = .low_pass,
            .cutoff = zang.constant(temp_float7),
            .res = 0.3,
        });
    }
};

const _module13 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
    };

    field0: _module12,
    tracker0: zang.Notes(_track0.Params).NoteTracker,
    trigger0: zang.Trigger(_track0.Params),

    pub fn init() _module13 {
        return .{
            .field0 = _module12.init(),
            .tracker0 = zang.Notes(_track0.Params).NoteTracker.init(&_track0.notes),
            .trigger0 = zang.Trigger(_track0.Params).init(),
        };
    }

    pub fn paint(self: *_module13, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / 1.0, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            const temp_float0 = params.freq_mul * _result.params.freq;
            self.field0.paint(_result.span, .{outputs[0]}, .{temps[0], temps[1], temps[2]}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = temp_float0,
                .note_on = _result.params.note_on,
            });
        }
    }
};

const _module14 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
    };
    pub const NoteParams = struct {
    };

    field0: _module12,
    tracker0: zang.Notes(_track1.Params).NoteTracker,
    trigger0: zang.Trigger(_track1.Params),

    pub fn init() _module14 {
        return .{
            .field0 = _module12.init(),
            .tracker0 = zang.Notes(_track1.Params).NoteTracker.init(&_track1.notes),
            .trigger0 = zang.Trigger(_track1.Params).init(),
        };
    }

    pub fn paint(self: *_module14, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / 0.8, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            self.field0.paint(_result.span, .{outputs[0]}, .{temps[0], temps[1], temps[2]}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = _result.params.freq,
                .note_on = _result.params.note_on,
            });
        }
    }
};

const _module15 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
    };
    pub const NoteParams = struct {
    };

    field0: _module12,
    tracker0: zang.Notes(_track2.Params).NoteTracker,
    trigger0: zang.Trigger(_track2.Params),

    pub fn init() _module15 {
        return .{
            .field0 = _module12.init(),
            .tracker0 = zang.Notes(_track2.Params).NoteTracker.init(&_track2.notes),
            .trigger0 = zang.Trigger(_track2.Params).init(),
        };
    }

    pub fn paint(self: *_module15, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / 0.8, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            self.field0.paint(_result.span, .{outputs[0]}, .{temps[0], temps[1], temps[2]}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = _result.params.freq,
                .note_on = _result.params.note_on,
            });
        }
    }
};

const _module16 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq: f32,
        note_on: bool,
    };
    pub const NoteParams = struct {
        freq: f32,
        note_on: bool,
    };

    field0: mod.PulseOsc,
    field1: mod.Envelope,

    pub fn init() _module16 {
        return .{
            .field0 = mod.PulseOsc.init(),
            .field1 = mod.Envelope.init(),
        };
    }

    pub fn paint(self: *_module16, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field0.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.constant(params.freq),
            .color = 0.5,
        });
        zang.zero(span, temps[1]);
        self.field1.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .attack = .{ .linear = 0.01 },
            .decay = .{ .linear = 0.1 },
            .release = .{ .linear = 0.15 },
            .sustain_volume = 0.5,
            .note_on = params.note_on,
        });
        zang.zero(span, temps[2]);
        zang.multiplyScalar(span, temps[2], temps[1], 0.25);
        zang.multiply(span, outputs[0], temps[0], temps[2]);
    }
};

const _module17 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
    };
    pub const NoteParams = struct {
    };

    field0: _module16,
    tracker0: zang.Notes(_track3.Params).NoteTracker,
    trigger0: zang.Trigger(_track3.Params),

    pub fn init() _module17 {
        return .{
            .field0 = _module16.init(),
            .tracker0 = zang.Notes(_track3.Params).NoteTracker.init(&_track3.notes),
            .trigger0 = zang.Trigger(_track3.Params).init(),
        };
    }

    pub fn paint(self: *_module17, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / 8.0, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            self.field0.paint(_result.span, .{outputs[0]}, .{temps[0], temps[1], temps[2]}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = _result.params.freq,
                .note_on = _result.params.note_on,
            });
        }
    }
};

const _module18 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        playback_speed: f32,
    };
    pub const NoteParams = struct {
        playback_speed: f32,
    };

    field0: _module16,
    tracker0: zang.Notes(_track4.Params).NoteTracker,
    trigger0: zang.Trigger(_track4.Params),

    pub fn init() _module18 {
        return .{
            .field0 = _module16.init(),
            .tracker0 = zang.Notes(_track4.Params).NoteTracker.init(&_track4.notes),
            .trigger0 = zang.Trigger(_track4.Params).init(),
        };
    }

    pub fn paint(self: *_module18, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        const temp_float0 = 8.0 * params.playback_speed;
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / temp_float0, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            const temp_float1 = _result.params.freq * params.playback_speed;
            self.field0.paint(_result.span, .{outputs[0]}, .{temps[0], temps[1], temps[2]}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = temp_float1,
                .note_on = _result.params.note_on,
            });
        }
    }
};

const _module19 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
    };

    field0: mod.PulseOsc,
    field1: mod.Envelope,
    tracker0: zang.Notes(_track5.Params).NoteTracker,
    trigger0: zang.Trigger(_track5.Params),

    pub fn init() _module19 {
        return .{
            .field0 = mod.PulseOsc.init(),
            .field1 = mod.Envelope.init(),
            .tracker0 = zang.Notes(_track5.Params).NoteTracker.init(&_track5.notes),
            .trigger0 = zang.Trigger(_track5.Params).init(),
        };
    }

    pub fn paint(self: *_module19, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        if (note_id_changed) {
            self.tracker0.reset();
            self.trigger0.reset();
        }
        const _iap0 = self.tracker0.consume(params.sample_rate / 1.0, span.end - span.start);
        var _ctr0 = self.trigger0.counter(span, _iap0);
        while (self.trigger0.next(&_ctr0)) |_result| {
            const _new_note = note_id_changed or _result.note_id_changed;
            const temp_float0 = params.freq_mul * _result.params.freq;
            zang.zero(_result.span, temps[0]);
            self.field0.paint(_result.span, .{temps[0]}, .{}, _new_note, .{
                .sample_rate = params.sample_rate,
                .freq = zang.constant(temp_float0),
                .color = 0.5,
            });
            zang.zero(_result.span, temps[1]);
            self.field1.paint(_result.span, .{temps[1]}, .{}, _new_note, .{
                .sample_rate = params.sample_rate,
                .attack = .instantaneous,
                .decay = .instantaneous,
                .release = .{ .linear = 0.04 },
                .sustain_volume = 1.0,
                .note_on = _result.params.note_on,
            });
            zang.zero(_result.span, temps[2]);
            zang.multiplyScalar(_result.span, temps[2], temps[1], 0.25);
            zang.multiply(_result.span, outputs[0], temps[0], temps[2]);
        }
    }
};

const _module20 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 3;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
        carrier_mul: f32,
        modulator_mul: f32,
        modulator_rad: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
        carrier_mul: f32,
        modulator_mul: f32,
        modulator_rad: f32,
    };

    field0: mod.SineOsc,
    field1: mod.Curve,
    field2: mod.SineOsc,
    field3: mod.Curve,
    field4: mod.Curve,

    pub fn init() _module20 {
        return .{
            .field0 = mod.SineOsc.init(),
            .field1 = mod.Curve.init(),
            .field2 = mod.SineOsc.init(),
            .field3 = mod.Curve.init(),
            .field4 = mod.Curve.init(),
        };
    }

    pub fn paint(self: *_module20, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field1.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve0,
        });
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[0], params.freq_mul);
        zang.zero(span, temps[0]);
        zang.multiplyScalar(span, temps[0], temps[1], params.carrier_mul);
        zang.zero(span, temps[1]);
        self.field3.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve0,
        });
        zang.zero(span, temps[2]);
        zang.multiplyScalar(span, temps[2], temps[1], params.freq_mul);
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[2], params.modulator_mul);
        zang.zero(span, temps[2]);
        self.field2.paint(span, .{temps[2]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[1]),
            .phase = zang.constant(0.0),
        });
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[2], params.modulator_rad);
        zang.zero(span, temps[2]);
        self.field0.paint(span, .{temps[2]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[0]),
            .phase = zang.buffer(temps[1]),
        });
        zang.zero(span, temps[0]);
        self.field4.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve1,
        });
        zang.multiply(span, outputs[0], temps[2], temps[0]);
    }
};

const _module21 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 4;
    pub const Params = struct {
        sample_rate: f32,
    };
    pub const NoteParams = struct {
    };

    field0: mod.Curve,
    field1: mod.Filter,
    field2: mod.Noise,
    field3: mod.Curve,

    pub fn init() _module21 {
        return .{
            .field0 = mod.Curve.init(),
            .field1 = mod.Filter.init(),
            .field2 = mod.Noise.init(),
            .field3 = mod.Curve.init(),
        };
    }

    pub fn paint(self: *_module21, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field0.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve2,
        });
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[0], std.math.pi);
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[2][i] = temps[1][i] / params.sample_rate;
            }
        }
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[1][i] = std.math.cos(temps[2][i]);
            }
        }
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[2][i] = 1.0 - temps[1][i];
            }
        }
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[2], 2.0);
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[2][i] = std.math.min(1.0, temps[1][i]);
            }
        }
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[1][i] = std.math.max(0.0, temps[2][i]);
            }
        }
        {
            var i = span.start;
            while (i < span.end) : (i += 1) {
                temps[2][i] = std.math.sqrt(temps[1][i]);
            }
        }
        zang.zero(span, temps[1]);
        self.field2.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .color = .white,
        });
        zang.zero(span, temps[3]);
        self.field1.paint(span, .{temps[3]}, .{}, note_id_changed, .{
            .input = temps[1],
            .type = .low_pass,
            .cutoff = zang.buffer(temps[2]),
            .res = 0.0,
        });
        zang.zero(span, temps[1]);
        self.field3.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve3,
        });
        zang.multiply(span, outputs[0], temps[3], temps[1]);
    }
};

const _module22 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 4;
    pub const Params = struct {
        sample_rate: f32,
    };
    pub const NoteParams = struct {
    };

    field0: mod.Curve,
    field1: mod.Curve,
    field2: mod.Filter,
    field3: mod.PulseOsc,

    pub fn init() _module22 {
        return .{
            .field0 = mod.Curve.init(),
            .field1 = mod.Curve.init(),
            .field2 = mod.Filter.init(),
            .field3 = mod.PulseOsc.init(),
        };
    }

    pub fn paint(self: *_module22, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field0.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .linear,
            .curve = &_curve4,
        });
        zang.zero(span, temps[1]);
        self.field1.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve5,
        });
        zang.zero(span, temps[2]);
        self.field3.paint(span, .{temps[2]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[0]),
            .color = 0.5,
        });
        zang.zero(span, temps[3]);
        zang.multiply(span, temps[3], temps[2], temps[1]);
        self.field2.paint(span, .{outputs[0]}, .{}, note_id_changed, .{
            .input = temps[3],
            .type = .low_pass,
            .cutoff = zang.constant(0.5),
            .res = 0.0,
        });
    }
};

const _module23 = struct {
    pub const num_outputs = 1;
    pub const num_temps = 5;
    pub const Params = struct {
        sample_rate: f32,
        freq_mul: f32,
    };
    pub const NoteParams = struct {
        freq_mul: f32,
    };

    field0: mod.SineOsc,
    field1: mod.Curve,
    field2: mod.Curve,
    field3: mod.SineOsc,
    field4: mod.SineOsc,
    field5: mod.Filter,

    pub fn init() _module23 {
        return .{
            .field0 = mod.SineOsc.init(),
            .field1 = mod.Curve.init(),
            .field2 = mod.Curve.init(),
            .field3 = mod.SineOsc.init(),
            .field4 = mod.SineOsc.init(),
            .field5 = mod.Filter.init(),
        };
    }

    pub fn paint(self: *_module23, span: zang.Span, outputs: [num_outputs][]f32, temps: [num_temps][]f32, note_id_changed: bool, params: Params) void {
        zang.zero(span, temps[0]);
        self.field0.paint(span, .{temps[0]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.constant(16.0),
            .phase = zang.constant(0.0),
        });
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[0], 0.4);
        zang.zero(span, temps[0]);
        zang.addScalar(span, temps[0], temps[1], 1.0);
        zang.zero(span, temps[1]);
        zang.multiplyScalar(span, temps[1], temps[0], 15.0);
        zang.zero(span, temps[2]);
        self.field1.paint(span, .{temps[2]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .smoothstep,
            .curve = &_curve6,
        });
        zang.zero(span, temps[3]);
        zang.multiply(span, temps[3], temps[1], temps[2]);
        zang.zero(span, temps[1]);
        self.field2.paint(span, .{temps[1]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .function = .linear,
            .curve = &_curve7,
        });
        zang.zero(span, temps[2]);
        zang.multiplyScalar(span, temps[2], temps[3], 2.0);
        zang.zero(span, temps[4]);
        self.field4.paint(span, .{temps[4]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[2]),
            .phase = zang.constant(0.0),
        });
        zang.zero(span, temps[2]);
        self.field3.paint(span, .{temps[2]}, .{}, note_id_changed, .{
            .sample_rate = params.sample_rate,
            .freq = zang.buffer(temps[3]),
            .phase = zang.buffer(temps[4]),
        });
        zang.zero(span, temps[4]);
        zang.multiply(span, temps[4], temps[1], temps[2]);
        self.field5.paint(span, .{outputs[0]}, .{}, note_id_changed, .{
            .input = temps[4],
            .type = .high_pass,
            .cutoff = zang.constant(0.02),
            .res = 0.0,
        });
    }
};
