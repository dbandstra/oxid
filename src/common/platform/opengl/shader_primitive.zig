const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const c = @import("../c.zig");
const debug_gl = @import("debug_gl.zig");
const math3d = @import("math3d.zig");
const shaders = @import("shaders.zig");

pub const BindParams = struct{
  mvp: *const math3d.Mat4x4,
  color: [4]f32,
  vertex_buffer: c.GLuint,
};

pub const Shader = struct{
  program: shaders.Program,
  attrib_position: c.GLint,
  uniform_mvp: c.GLint,
  uniform_color: c.GLint,

  pub fn bind(self: Shader, params: BindParams) void {
    c.glUseProgram(self.program.program_id);

    if (self.uniform_color != -1) {
      c.glUniform4fv(self.uniform_color, 1, params.color[0..].ptr);
    }
    if (self.uniform_mvp != -1) {
      c.glUniformMatrix4fv(self.uniform_mvp, 1, c.GL_FALSE, params.mvp.data[0][0..].ptr);
    }

    c.glBindBuffer(c.GL_ARRAY_BUFFER, params.vertex_buffer);
    c.glEnableVertexAttribArray(@intCast(c.GLuint, self.attrib_position));
    c.glVertexAttribPointer(@intCast(c.GLuint, self.attrib_position), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
  }
};

fn getSource(comptime version: shaders.GLSLVersion) shaders.ShaderSource {
  const old = version == shaders.GLSLVersion.V120;

  return shaders.ShaderSource{
    .vertex =
      "#version " ++ (if (old) "120" else "130") ++ "\n"
      ++
      (if (old) "attribute" else "in") ++ " vec3 VertexPosition;\n"
      ++
      \\uniform mat4 MVP;
      \\
      \\void main(void) {
      \\  gl_Position = vec4(VertexPosition, 1.0) * MVP;
      \\}
    ,
    .fragment =
      "#version " ++ (if (old) "120" else "130") ++ "\n"
      ++
      (if (old) "" else "out vec4 FragColor;\n")
      ++
      \\uniform vec4 Color;
      \\
      \\void main(void) {
      \\
      ++
      "  " ++ (if (old) "gl_" else "") ++ "FragColor = Color;\n"
      ++
      \\}
    ,
  };
}

pub fn create(hunk_side: *HunkSide, version: shaders.GLSLVersion) shaders.InitError!Shader {
  errdefer std.debug.warn("Failed to create primitive shader program.\n");

  defer debug_gl.assertNoError();

  const program = try shaders.compileAndLink(
    hunk_side,
    "primitive",
    switch (version) {
      shaders.GLSLVersion.V120 => getSource(shaders.GLSLVersion.V120),
      shaders.GLSLVersion.V130 => getSource(shaders.GLSLVersion.V130),
    },
  );

  return Shader{
    .program = program,
    .attrib_position = try shaders.getAttribLocation(program, c"VertexPosition"),
    .uniform_mvp = shaders.getUniformLocation(program, c"MVP"),
    .uniform_color = shaders.getUniformLocation(program, c"Color"),
  };
}
