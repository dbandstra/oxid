const std = @import("std");
const Draw = @import("common/draw.zig");
const Math = @import("common/math.zig");
const lessThanField = @import("common/util.zig").lessThanField;

// TODO - reorganize?

// decrements the timer. return true if it just hit zero (but not if it was
// already at zero
pub fn decrementTimer(timer: *u32) bool {
  if (timer.* > 0) {
    timer.* -= 1;
    if (timer.* == 0) {
      return true;
    }
  }
  return false;
}

pub fn getDirTransform(direction: Math.Direction) Draw.Transform {
  return switch (direction) {
    Math.Direction.N => Draw.Transform.RotateCounterClockwise,
    Math.Direction.E => Draw.Transform.Identity,
    Math.Direction.S => Draw.Transform.RotateClockwise,
    Math.Direction.W => Draw.Transform.FlipHorizontal,
  };
}

pub const Choice = struct{
  direction: Math.Direction,
  score: u32, // lower is better
};

pub const Choices = struct{
  choices: [4]Choice,
  num_choices: usize,

  pub fn init() Choices {
    return Choices{
      .choices = undefined,
      .num_choices = 0,
    };
  }

  pub fn add(self: *Choices, direction: Math.Direction, score: u32) void {
    self.choices[self.num_choices] = Choice{
      .direction = direction,
      .score = score,
    };
    self.num_choices += 1;
  }

  pub fn choose(self: *Choices) ?Math.Direction {
    if (self.num_choices > 0) {
      // TODO - use random if there is a tie.
      std.sort.sort(Choice, self.choices[0..self.num_choices], lessThanField(Choice, "score"));
      return self.choices[0].direction;
    } else {
      return null;
    }
  }
};
