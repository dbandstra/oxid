usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
});

const std = @import("std");
const HunkSide = @import("zig-hunk").HunkSide;
const math3d = @import("math3d.zig");

pub const GLSLVersion = enum{ V120, V130 };

pub const ShaderSource = struct{
    vertex: []const u8,
    fragment: []const u8,
};

pub const Program = struct{
    program_id: GLuint,
    vertex_id: GLuint,
    fragment_id: GLuint,
};

pub const InitError = error{
    ShaderCompileFailed,
    ShaderLinkFailed,
    ShaderInvalidAttrib,
};

pub fn compileAndLink(hunk_side: *HunkSide, description: []const u8, source: ShaderSource) InitError!Program {
    errdefer std.debug.warn("Failed to compile and link shader program \"{}\".\n", description);

    const vertex_id = try compile(hunk_side, source.vertex, "vertex", GL_VERTEX_SHADER);
    const fragment_id = try compile(hunk_side, source.fragment, "fragment", GL_FRAGMENT_SHADER);

    const program_id = glCreateProgram();
    glAttachShader(program_id, vertex_id);
    glAttachShader(program_id, fragment_id);
    glLinkProgram(program_id);

    var ok: GLint = undefined;
    glGetProgramiv(program_id, GL_LINK_STATUS, &ok);
    if (ok != 0) {
        return Program{
            .program_id = program_id,
            .vertex_id = vertex_id,
            .fragment_id = fragment_id,
        };
    } else {
        var error_size: GLint = undefined;
        glGetProgramiv(program_id, GL_INFO_LOG_LENGTH, &error_size);
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);
        if (hunk_side.allocator.alloc(u8, @intCast(usize, error_size))) |message| {
            glGetProgramInfoLog(program_id, error_size, &error_size, message.ptr);
            std.debug.warn("PROGRAM INFO LOG:\n{s}\n", message.ptr);
        } else |_| {
            std.debug.warn("Failed to retrieve program info log (out of memory).\n");
        }
        return error.ShaderLinkFailed;
    }
}

fn compile(hunk_side: *HunkSide, source: []const u8, shader_type: []const u8, kind: GLenum) InitError!GLuint {
    errdefer std.debug.warn("Failed to compile {} shader.\n", shader_type);

    const shader_id = glCreateShader(kind);
    const source_ptr: ?[*]const u8 = source.ptr;
    const source_len = @intCast(GLint, source.len);
    glShaderSource(shader_id, 1, &source_ptr, &source_len);
    glCompileShader(shader_id);

    var ok: GLint = undefined;
    glGetShaderiv(shader_id, GL_COMPILE_STATUS, &ok);
    if (ok != 0) {
        return shader_id;
    } else {
        var error_size: GLint = undefined;
        glGetShaderiv(shader_id, GL_INFO_LOG_LENGTH, &error_size);
        const mark = hunk_side.getMark();
        defer hunk_side.freeToMark(mark);
        if (hunk_side.allocator.alloc(u8, @intCast(usize, error_size))) |message| {
            glGetShaderInfoLog(shader_id, error_size, &error_size, message.ptr);
            std.debug.warn("SHADER INFO LOG:\n{s}\n", message.ptr);
        } else |_| {
            std.debug.warn("Failed to retrieve shader info log (out of memory).\n");
        }
        return error.ShaderCompileFailed;
    }
}

pub fn destroy(sp: Program) void {
    glDetachShader(sp.program_id, sp.fragment_id);
    glDetachShader(sp.program_id, sp.vertex_id);

    glDeleteShader(sp.fragment_id);
    glDeleteShader(sp.vertex_id);

    glDeleteProgram(sp.program_id);
}

pub fn getAttribLocation(sp: Program, name: [*]const u8) !GLint {
    const id = glGetAttribLocation(sp.program_id, name);
    if (id == -1) {
        std.debug.warn("invalid attrib: {s}\n", name);
        return error.ShaderInvalidAttrib;
    }
    return id;
}

pub fn getUniformLocation(sp: Program, name: [*]const u8) GLint {
    const id = glGetUniformLocation(sp.program_id, name);
    if (id == -1) {
        std.debug.warn("(warning) invalid uniform: {s}\n", name);
    }
    return id;
}
