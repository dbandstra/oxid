const std = @import("std");
const StackAllocator = @import("../../../zigutils/src/traits/StackAllocator.zig").StackAllocator;
const c = @import("../c.zig");
const debug_gl = @import("debug_gl.zig");
const math3d = @import("math3d.zig");
const shaders = @import("shaders.zig");
const static_geometry = @import("static_geometry.zig");

pub const BindParams = struct{
  mvp: *const math3d.Mat4x4,
  tex: c.GLint,
  alpha: f32,
  vertex_buffer: ?c.GLuint,
  texcoord_buffer: ?c.GLuint,
};

pub const UpdateParams = struct{
  vertex_buffer: c.GLuint,
  texcoord_buffer: c.GLuint,
  vertex2f: []f32,
  texcoord2f: []f32,
};

pub const Shader = struct{
  program: shaders.Program,
  attrib_texcoord: c.GLint,
  attrib_position: c.GLint,
  uniform_mvp: c.GLint,
  uniform_tex: c.GLint,
  uniform_alpha: c.GLint,

  pub fn bind(self: Shader, params: BindParams) void {
    c.glUseProgram(self.program.program_id);

    if (self.uniform_tex != -1) {
      c.glUniform1i(self.uniform_tex, params.tex);
    }
    if (self.uniform_alpha != -1) {
      c.glUniform1f(self.uniform_alpha, params.alpha);
    }
    if (self.uniform_mvp != -1) {
      c.glUniformMatrix4fv(self.uniform_mvp, 1, c.GL_FALSE, params.mvp.data[0][0..].ptr);
    }

    c.glEnableVertexAttribArray(@intCast(c.GLuint, self.attrib_position));
    if (params.vertex_buffer) |vertex_buffer| {
      c.glBindBuffer(c.GL_ARRAY_BUFFER, vertex_buffer);
      c.glVertexAttribPointer(@intCast(c.GLuint, self.attrib_position), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
    }

    c.glEnableVertexAttribArray(@intCast(c.GLuint, self.attrib_texcoord));
    if (params.texcoord_buffer) |texcoord_buffer| {
      c.glBindBuffer(c.GL_ARRAY_BUFFER, texcoord_buffer);
      c.glVertexAttribPointer(@intCast(c.GLuint, self.attrib_texcoord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
    }
  }

  pub fn update(self: Shader, params: UpdateParams) void {
    static_geometry.updateVbo(params.vertex_buffer, params.vertex2f);
    c.glVertexAttribPointer(@intCast(c.GLuint, self.attrib_position), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);

    static_geometry.updateVbo(params.texcoord_buffer, params.texcoord2f);
    c.glVertexAttribPointer(@intCast(c.GLuint, self.attrib_texcoord), 2, c.GL_FLOAT, c.GL_FALSE, 0, null);
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
      (if (old) "attribute" else "in") ++ " vec2 TexCoord;\n"
      ++
      (if (old) "varying" else "out") ++ " vec2 FragTexCoord;\n"
      ++
      \\uniform mat4 MVP;
      \\
      \\void main(void)
      \\{
      \\  FragTexCoord = TexCoord;
      \\  gl_Position = vec4(VertexPosition, 1.0) * MVP;
      \\}
    ,
    .fragment =
      "#version " ++ (if (old) "120" else "130") ++ "\n"
      ++
      (if (old) "varying" else "in") ++ " vec2 FragTexCoord;\n"
      ++
      (if (old) "" else "out vec4 FragColor;\n")
      ++
      \\uniform sampler2D Tex;
      \\uniform float Alpha;
      \\
      \\void main(void)
      \\{
      \\
      ++
      "  " ++ (if (old) "gl_" else "") ++ "FragColor = texture2D(Tex, FragTexCoord);\n"
      ++
      "  " ++ (if (old) "gl_" else "") ++ "FragColor.a *= Alpha;\n"
      ++
      \\}
    ,
  };
}

pub fn create(stack: *StackAllocator, glsl_version: shaders.GLSLVersion) shaders.InitError!Shader {
  errdefer std.debug.warn("Failed to create textured shader program.\n");

  defer debug_gl.assertNoError();

  const program = try shaders.compileAndLink(
    stack,
    "textured",
    switch (glsl_version) {
      shaders.GLSLVersion.V120 => getSource(shaders.GLSLVersion.V120),
      shaders.GLSLVersion.V130 => getSource(shaders.GLSLVersion.V130),
    },
  );

  return Shader{
    .program = program,
    .attrib_position = try shaders.getAttribLocation(program, c"VertexPosition"),
    .attrib_texcoord = try shaders.getAttribLocation(program, c"TexCoord"),
    .uniform_mvp = shaders.getUniformLocation(program, c"MVP"),
    .uniform_tex = shaders.getUniformLocation(program, c"Tex"),
    .uniform_alpha = shaders.getUniformLocation(program, c"Alpha"),
  };
}
