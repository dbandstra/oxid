const std = @import("std");
const StackAllocator = @import("../../../zigutils/src/traits/StackAllocator.zig").StackAllocator;
const c = @import("../c.zig");
const math3d = @import("math3d.zig");
const debug_gl = @import("debug_gl.zig");

pub const GLSLVersion = enum{ V120, V130 };

pub const ShaderSource = struct{
  vertex: []const u8,
  fragment: []const u8,
};

pub const Program = struct{
  program_id: c.GLuint,
  vertex_id: c.GLuint,
  fragment_id: c.GLuint,
};

pub fn compileAndLink(stack: *StackAllocator, description: []const u8, source: ShaderSource) !Program {
  errdefer std.debug.warn("Failed to compile and link shader program \"{}\".\n", description);

  const vertex_id = try compile(stack, source.vertex, "vertex", c.GL_VERTEX_SHADER);
  const fragment_id = try compile(stack, source.fragment, "fragment", c.GL_FRAGMENT_SHADER);

  const program_id = c.glCreateProgram();
  c.glAttachShader(program_id, vertex_id);
  c.glAttachShader(program_id, fragment_id);
  c.glLinkProgram(program_id);

  var ok: c.GLint = undefined;
  c.glGetProgramiv(program_id, c.GL_LINK_STATUS, c.ptr(&ok));
  if (ok != 0) {
    return Program{
      .program_id = program_id,
      .vertex_id = vertex_id,
      .fragment_id = fragment_id,
    };
  } else {
    var error_size: c.GLint = undefined;
    c.glGetProgramiv(program_id, c.GL_INFO_LOG_LENGTH, c.ptr(&error_size));
    const mark = stack.get_mark();
    defer stack.free_to_mark(mark);
    const message = try stack.allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetProgramInfoLog(program_id, error_size, c.ptr(&error_size), message.ptr);
    std.debug.warn("PROGRAM INFO LOG:\n{s}\n", message.ptr);
    return error.ShaderError;
  }
}

fn compile(stack: *StackAllocator, source: []const u8, shader_type: []const u8, kind: c.GLenum) !c.GLuint {
  errdefer std.debug.warn("Failed to compile {} shader.\n", shader_type);

  const shader_id = c.glCreateShader(kind);
  const source_ptr: ?[*]const u8 = source.ptr;
  const source_len = @intCast(c.GLint, source.len);
  c.glShaderSource(shader_id, 1, c.ptr(&source_ptr), c.ptr(&source_len));
  c.glCompileShader(shader_id);

  var ok: c.GLint = undefined;
  c.glGetShaderiv(shader_id, c.GL_COMPILE_STATUS, c.ptr(&ok));
  if (ok != 0) {
    return shader_id;
  } else {
    var error_size: c.GLint = undefined;
    c.glGetShaderiv(shader_id, c.GL_INFO_LOG_LENGTH, c.ptr(&error_size));
    const mark = stack.get_mark();
    defer stack.free_to_mark(mark);
    const message = try stack.allocator.alloc(u8, @intCast(usize, error_size));
    c.glGetShaderInfoLog(shader_id, error_size, c.ptr(&error_size), message.ptr);
    std.debug.warn("SHADER INFO LOG:\n{s}\n", message.ptr);
    return error.ShaderError;
  }
}

pub fn destroy(sp: Program) void {
  c.glDetachShader(sp.program_id, sp.fragment_id);
  c.glDetachShader(sp.program_id, sp.vertex_id);

  c.glDeleteShader(sp.fragment_id);
  c.glDeleteShader(sp.vertex_id);

  c.glDeleteProgram(sp.program_id);
}

pub fn getAttribLocation(sp: Program, name: [*]const u8) !c.GLint {
  const id = c.glGetAttribLocation(sp.program_id, name);
  if (id == -1) {
    std.debug.warn("invalid attrib: {s}\n", name);
    return error.ShaderInvalidAttrib;
  }
  return id;
}

pub fn getUniformLocation(sp: Program, name: [*]const u8) c.GLint {
  const id = c.glGetUniformLocation(sp.program_id, name);
  if (id == -1) {
    std.debug.warn("(warning) invalid uniform: {s}\n", name);
  }
  return id;
}
