usingnamespace if (@import("builtin").arch == .wasm32)
    @import("../../web.zig")
else
    @import("gl").namespace;
const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const warn = @import("../../warn.zig").warn;
const warnWriter = @import("../../warn.zig").warnWriter;
const flushWarnWriter = @import("../../warn.zig").flushWarnWriter;
const indentingWriter = @import("../../common/indenting_writer.zig").indentingWriter;

pub const GLSLVersion = enum { v120, v130, webgl };

pub const ShaderSource = struct {
    vertex: []const u8,
    fragment: []const u8,
};

pub const Program = struct {
    program_id: GLuint,
    vertex_id: GLuint,
    fragment_id: GLuint,
};

pub const InitError = error{
    ShaderCompileFailed,
    ShaderLinkFailed,
    ShaderInvalidAttrib,
};

pub fn compileAndLink(
    hunk_side: *HunkSide,
    description: []const u8,
    source: ShaderSource,
) InitError!Program {
    errdefer warn("Failed to compile and link shader program \"{}\".\n", .{description});

    const vertex_id = try compile(hunk_side, source.vertex, "vertex", GL_VERTEX_SHADER);
    const fragment_id = try compile(hunk_side, source.fragment, "fragment", GL_FRAGMENT_SHADER);

    const program_id = glCreateProgram();
    glAttachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    glLinkProgram(program_id);

    var status: GLint = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        var buffer_size: GLint = undefined;
        glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &buffer_size);

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        if (hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1)) |buffer| {
            var len: GLsizei = 0;
            glGetProgramInfoLog(program_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
            const log = buffer[0..@intCast(usize, len)];
            indentingWriter(warnWriter(), 4).writer().writeAll(log) catch {};
            flushWarnWriter();
        } else |_| warn("Failed to retrieve program info log (out of memory).\n", .{});

        return error.ShaderLinkFailed;
    }

    return Program{
        .program_id = program_id,
        .vertex_id = vertex_id,
        .fragment_id = fragment_id,
    };
}

fn compile(hunk_side: *HunkSide, source: []const u8, shader_type: []const u8, kind: GLenum) InitError!GLuint {
    errdefer warn("Failed to compile {} shader.\n", .{shader_type});

    const shader_id = glCreateShader(kind);
    const source_len = @intCast(GLint, source.len);
    glShaderSource(shader_id, 1, &source.ptr, &source_len);
    glCompileShader(shader_id);

    var status: GLint = undefined;
    glGetShaderiv(shader_id, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        var buffer_size: GLint = undefined;
        glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &buffer_size);

        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);

        if (hunk_side.allocator.alloc(u8, @intCast(usize, buffer_size) + 1)) |buffer| {
            var len: GLsizei = 0;
            glGetShaderInfoLog(shader_id, @intCast(GLsizei, buffer.len), &len, buffer.ptr);
            const log = buffer[0..@intCast(usize, len)];
            indentingWriter(warnWriter(), 4).writer().writeAll(log) catch {};
            flushWarnWriter();
        } else |_| warn("Failed to retrieve shader info log (out of memory).\n", .{});

        return error.ShaderCompileFailed;
    }

    return shader_id;
}

pub fn destroy(sp: Program) void {
    glDetachShader(sp.program_id, sp.fragment_id);
    glDetachShader(sp.program_id, sp.vertex_id);

    glDeleteShader(sp.fragment_id);
    glDeleteShader(sp.vertex_id);

    glDeleteProgram(sp.program_id);
}

pub fn getAttribLocation(sp: Program, name: [:0]const u8) GLint {
    const id = glGetAttribLocation(sp.program_id, name);
    if (id == -1) {
        warn("(warning) invalid attrib: {}\n", .{name});
    }
    return id;
}

pub fn getUniformLocation(sp: Program, name: [:0]const u8) GLint {
    const id = glGetUniformLocation(sp.program_id, name);
    if (id == -1) {
        warn("(warning) invalid uniform: {}\n", .{name});
    }
    return id;
}
