const std = @import("std");
const Math = @import("../math.zig");
const lessThanField = @import("../util.zig").lessThanField;

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

pub const Choice = struct{
  direction: Math.Direction,
  score: u32, // lower is better
};

pub const Choices = struct{
  choices: [4]Choice,
  num_choices: usize,

  fn init() Choices {
    return Choices{
      .choices = undefined,
      .num_choices = 0,
    };
  }

  fn add(self: *Choices, direction: Math.Direction, score: u32) void {
    self.choices[self.num_choices] = Choice{
      .direction = direction,
      .score = score,
    };
    self.num_choices += 1;
  }

  fn choose(self: *Choices) ?Math.Direction {
    if (self.num_choices > 0) {
      // TODO - use random if there is a tie.
      std.sort.sort(Choice, self.choices[0..self.num_choices], lessThanField(Choice, "score"));
      return self.choices[0].direction;
    } else {
      return null;
    }
  }
};
