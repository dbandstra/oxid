const std = @import("std");
const zang = @import("zang");

// expects ModuleType to have `paint` method
pub fn VoiceBase(comptime ModuleType: type, comptime num_temp_bufs: usize) type {
  return struct {
    iq: zang.ImpulseQueue,
    sub_frame_index: usize,
    note_id: usize,
    freq: f32,

    pub fn init() @This() {
      return @This() {
        .iq = zang.ImpulseQueue.init(),
        .sub_frame_index = 0,
        .note_id = 0,
        .freq = 0.0,
      };
    }

    pub fn update(
      base: *@This(),
      module: *ModuleType,
      sample_rate: u32,
      out: []f32,
      tmp_bufs: [num_temp_bufs][]f32,
      frame_index: usize,
    ) void {
      var i: usize = 0;
      while (i < num_temp_bufs) : (i += 1) {
        std.debug.assert(out.len == tmp_bufs[i].len);
      }

      if (!base.iq.isEmpty()) {
        const track = base.iq.getImpulses();

        var start: usize = 0;

        while (start < out.len) {
          const note_span = zang.getNextNoteSpan(track, frame_index, start, out.len);

          std.debug.assert(note_span.start == start);
          std.debug.assert(note_span.end > start);
          std.debug.assert(note_span.end <= out.len);

          const buf_span = out[note_span.start .. note_span.end];
          var tmp_spans: [num_temp_bufs][]f32 = undefined;
          comptime var ci: usize = 0;
          comptime while (ci < num_temp_bufs) : (ci += 1) {
            tmp_spans[ci] = tmp_bufs[ci][note_span.start .. note_span.end];
          };

          if (note_span.note) |note| {
            if (note.id != base.note_id) {
              std.debug.assert(note.id > base.note_id);

              base.note_id = note.id;
              base.freq = note.freq;
              base.sub_frame_index = 0;
            }

            module.paint(sample_rate, buf_span, tmp_spans);
          }

          start = note_span.end;
        }
      }

      base.iq.flush(frame_index, out.len);
    }
  };
}
