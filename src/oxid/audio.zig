const std = @import("std");
const DoubleStackAllocatorFlat = @import("../../zigutils/src/DoubleStackAllocatorFlat.zig").DoubleStackAllocatorFlat;
const SeekableFileInStream = @import("../../zigutils/src/FileInStream.zig").SeekableFileInStream;
const Platform = @import("../platform/index.zig");

pub const Sample = enum.{
  Accelerate,
  Coin,
  DropWeb,
  ExtraLife,
  PlayerShot,
  PlayerScream,
  PlayerDeath,
  PlayerCrumble,
  PowerUp,
  MonsterImpact,
  MonsterShot,
  MonsterDeath,
  WaveBegin,
};

fn getSampleFilename(sample: Sample) []const u8 {
  return switch (sample) {
    Sample.Accelerate => "assets/null.wav",
    Sample.Coin => "assets/sfx_coin_double7.wav",
    Sample.DropWeb => "assets/sfx_sounds_interaction5.wav",
    Sample.ExtraLife => "assets/sfx_sounds_powerup4.wav",
    Sample.PlayerShot => "assets/sfx_wpn_laser8.wav",
    Sample.PlayerScream => "assets/sfx_deathscream_human2.wav",
    Sample.PlayerDeath => "assets/sfx_exp_cluster7.wav",
    Sample.PlayerCrumble => "assets/sfx_exp_short_soft10.wav",
    Sample.PowerUp => "assets/sfx_sounds_powerup10.wav",
    Sample.MonsterImpact => "assets/sfx_sounds_impact1.wav",
    Sample.MonsterShot => "assets/sfx_wpn_laser10.wav",
    Sample.MonsterDeath => "assets/sfx_exp_short_soft5.wav",
    Sample.WaveBegin => "assets/sfx_sound_mechanicalnoise2.wav",
  };
}

pub const LoadedSamples = struct.{
  handles: [@memberCount(Sample)]u32,
};

fn loadSample(ps: *Platform.State, filename: []const u8) u32 {
  var file = std.os.File.openRead(filename) catch |_| {
    std.debug.warn("couldn\'t open file {}\n", filename);
    return 0;
  };
  defer file.close();

  var file_stream = SeekableFileInStream.init(&file);
  var stream = &file_stream.stream;
  var seekable = &file_stream.seekable;

  return Platform.loadSound(ps, SeekableFileInStream.ReadError, stream, seekable);
}

pub fn loadSamples(ps: *Platform.State, ls: *LoadedSamples) void {
  var i: usize = 0;
  while (i < @memberCount(Sample)) : (i += 1) {
    const e = @intCast(@TagType(Sample), i);
    const sample = @intToEnum(Sample, e);
    const filename = getSampleFilename(sample);
    ls.handles[i] = loadSample(ps, filename);
  }
}

pub fn playSample(ps: *Platform.State, ls: *LoadedSamples, sample: Sample) void {
  const i = @enumToInt(sample);
  const handle = ls.handles[i];
  Platform.playSound(ps, handle);
}
