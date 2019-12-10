const std = @import("std");

const Func = struct {
    name: []const u8,
    args: []const Arg,
    ret: []const u8,
    js: []const u8,
};

const Arg = struct {
    name: []const u8,
    type: []const u8,
};

// TODO - i don't know what to put for GLboolean... i can't find an explicit
// mention anywhere on what size it should be
const zig_top =
    \\pub const GLenum = c_uint;
    \\pub const GLboolean = bool;
    \\pub const GLbitfield = c_uint;
    \\pub const GLbyte = i8;
    \\pub const GLshort = i16;
    \\pub const GLint = i32;
    \\pub const GLsizei = i32;
    \\pub const GLintptr = i64;
    \\pub const GLsizeiptr = i64;
    \\pub const GLubyte = u8;
    \\pub const GLushort = u16;
    \\pub const GLuint = u32;
    \\pub const GLfloat = f32;
    \\pub const GLclampf = f32;
;

// memory has to be wrapped in a getter because we need the "env" before we can
// even get the memory
const js_top =
    \\function getWebGLEnv(canvas_element, getMemory) {
    \\    const readCharStr = (ptr, len) => {
    \\        const bytes = new Uint8Array(getMemory().buffer, ptr, len);
    \\        let s = "";
    \\        for (let i = 0; i < len; ++i) {
    \\            s += String.fromCharCode(bytes[i]);
    \\        }
    \\        return s;
    \\    };
    \\
    \\    const gl = canvas_element.getContext('webgl', {
    \\        antialias: false,
    \\        preserveDrawingBuffer: true,
    \\    });
    \\
    \\    if (!gl) {
    \\        throw new Error('The browser does not support WebGL');
    \\    }
    \\
    \\    const glShaders = [];
    \\    const glPrograms = [];
    \\    const glBuffers = [];
    \\    const glTextures = [];
    \\    const glFramebuffers = [];
    \\    const glUniformLocations = [];
    \\
;

const js_bottom =
    \\}
;

const funcs = [_]Func {
    Func {
        .name = "glActiveTexture",
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.activeTexture(target);
    },
    Func {
        .name = "glAttachShader",
        .args = &[_]Arg {
            .{ .name = "program", .type = "c_uint" },
            .{ .name = "shader", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.attachShader(glPrograms[program], glShaders[shader]);
    },
    // TODO - glBindAttribLocation
    Func {
        .name = "glBindBuffer",
        .args = &[_]Arg {
            .{ .name = "type", .type = "c_uint" },
            .{ .name = "buffer_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindBuffer(type, glBuffers[buffer_id]);
    },
    Func {
        .name = "glBindFramebuffer",
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
            .{ .name = "framebuffer", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindFramebuffer(target, glFramebuffers[framebuffer]);
    },
    // TODO - glBindRenderbuffer
    Func {
        .name = "glBindTexture",
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
            .{ .name = "texture_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindTexture(target, glTextures[texture_id]);
    },
    // TODO - glBlendColor
    // TODO - glBlendEquation
    // TODO - glBlendEquationSeparate
    Func {
        .name = "glBlendFunc",
        .args = &[_]Arg {
            .{ .name = "x", .type = "c_uint" },
            .{ .name = "y", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.blendFunc(x, y);
    },
    // TODO - glBlendFuncSeparate
    Func {
        .name = "glBufferData",
        .args =& [_]Arg {
            .{ .name = "type", .type = "c_uint" },
            .{ .name = "count", .type = "c_uint" },
            .{ .name = "data_ptr", .type = "[*c]const f32" },
            .{ .name = "draw_type", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            // TODO - check for NULL?
            \\const floats = new Float32Array(getMemory().buffer, data_ptr, count);
            \\gl.bufferData(type, floats, draw_type);
    },
    // TODO - glBufferSubData
    Func {
        .name = "glCheckFramebufferStatus",
        .args = &[_]Arg {
            .{ .name = "target", .type = "GLenum" },
        },
        .ret = "GLenum",
        .js =
            \\return gl.checkFramebufferStatus(target);
    },
    Func {
        .name = "glClear",
        .args = &[_]Arg {
            .{ .name = "mask", .type = "GLbitfield" },
        },
        .ret = "void",
        .js =
            \\gl.clear(mask);
    },
    Func {
        .name = "glClearColor",
        .args = &[_]Arg {
            .{ .name = "r", .type = "f32" },
            .{ .name = "g", .type = "f32" },
            .{ .name = "b", .type = "f32" },
            .{ .name = "a", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.clearColor(r, g, b, a);
    },
    // TODO - glClearDepth
    // TODO - glClearStencil
    // TODO - glColorMask
    // TODO - glCommit
    Func {
        .name = "glCompileShader",
        .args = &[_]Arg {
            .{ .name = "shader", .type = "GLuint" },
        },
        .ret = "void",
        .js =
            // TODO don't call getShaderParameter here
            \\gl.compileShader(glShaders[shader]);
            \\if (!gl.getShaderParameter(glShaders[shader], gl.COMPILE_STATUS)) {
            \\    throw "Error compiling shader:" + gl.getShaderInfoLog(glShaders[shader]);
            \\}
    },
    // TODO - glCompressedTexImage2D
    // TODO - glCompressedTexImage3D
    // TODO - glCompressedTexSubImage2D
    // TODO - glCopyTexImage2D
    // TODO - glCopyTexSubImage2D
    Func {
        .name = "glCreateBuffer",
        .args = &[_]Arg {},
        .ret = "c_uint",
        .js =
            \\glBuffers.push(gl.createBuffer());
            \\return glBuffers.length - 1;
    },
    Func {
        .name = "glCreateFramebuffer",
        .args = &[_]Arg {},
        .ret = "GLuint",
        .js =
            \\glFramebuffers.push(gl.createFramebuffer());
            \\return glFramebuffers.length - 1;
    },
    Func {
        .name = "glCreateProgram",
        .args = &[_]Arg {},
        .ret = "GLuint",
        .js =
            \\glPrograms.push(gl.createProgram());
            \\return glPrograms.length - 1;
    },
    // TODO - glCreateRenderbuffer
    Func {
        .name = "glCreateShader",
        .args = &[_]Arg {
            .{ .name = "shader_type", .type = "GLenum" },
        },
        .ret = "GLuint",
        .js =
            \\glShaders.push(gl.createShader(shader_type));
            \\return glShaders.length - 1;
    },
    Func {
        .name = "glCreateTexture",
        .args = &[_]Arg {},
        .ret = "c_uint",
        .js =
            \\glTextures.push(gl.createTexture());
            \\return glTextures.length - 1;
    },
    // TODO - glCullFace
    Func {
        .name = "glDeleteBuffer",
        .args = &[_]Arg {
            .{ .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteBuffer(glBuffers[id]);
            \\glBuffers[id] = undefined;
    },
    // TODO - glDeleteFramebuffer
    Func {
        .name = "glDeleteProgram",
        .args = &[_]Arg {
            .{ .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteProgram(glPrograms[id]);
            \\glPrograms[id] = undefined;
    },
    // TODO - glDeleteRenderbuffer
    Func {
        .name = "glDeleteShader",
        .args = &[_]Arg {
            .{ .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteShader(glShaders[id]);
            \\glShaders[id] = undefined;
    },
    Func {
        .name = "glDeleteTexture",
        .args = &[_]Arg {
            .{ .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteTexture(glTextures[id]);
            \\glTextures[id] = undefined;
    },
    Func {
        .name = "glDepthFunc",
        .args = &[_]Arg {
            .{ .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.depthFunc(x);
    },
    // TODO - glDepthMask
    // TODO - glDepthRange
    Func {
        .name = "glDetachShader",
        .args = &[_]Arg {
            .{ .name = "program", .type = "c_uint" },
            .{ .name = "shader", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.detachShader(glPrograms[program], glShaders[shader]);
    },
    Func {
        .name = "glDisable",
        .args = &[_]Arg {
            .{ .name = "cap", .type = "GLenum" },
        },
        .ret = "void",
        .js =
            \\gl.disable(cap);
    },
    // TODO - glDisableVertexAttribArray
    Func {
        .name = "glDrawArrays",
        .args = &[_]Arg {
            .{ .name = "type", .type = "c_uint" },
            .{ .name = "offset", .type = "c_uint" },
            .{ .name = "count", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.drawArrays(type, offset, count);
    },
    // TODO - glDrawElements
    Func {
        .name = "glEnable",
        .args = &[_]Arg {
            .{ .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.enable(x);
    },
    Func {
        .name = "glEnableVertexAttribArray",
        .args = &[_]Arg {
            .{ .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.enableVertexAttribArray(x);
    },
    // TODO - glFinish
    // TODO - glFlush
    // TODO - glFramebufferRenderbuffer
    Func {
        .name = "glFramebufferTexture2D",
        .args = &[_]Arg {
            .{ .name = "target", .type = "GLenum" },
            .{ .name = "attachment", .type = "GLenum" },
            .{ .name = "textarget", .type = "GLenum" },
            .{ .name = "texture", .type = "GLuint" },
            .{ .name = "level", .type = "GLint" },
        },
        .ret = "void",
        .js =
            \\gl.framebufferTexture2D(target, attachment, textarget, glTextures[texture], level);
    },
    Func {
        .name = "glFrontFace",
        .args = &[_]Arg {
            .{ .name = "mode", .type = "GLenum" },
        },
        .ret = "void",
        .js =
            \\gl.frontFace(mode);
    },
    // TODO - glGenerateMipmap
    // TODO - glGetActiveAttrib
    // TODO - glGetActiveUniform
    // TODO - glGetAttachedShaders
    Func {
        .name = "glGetAttribLocation",
        .args = &[_]Arg {
            .{ .name = "program_id", .type = "c_uint" },
            .{ .name = "name", .type = "SLICE" },
        },
        .ret = "c_int",
        .js =
            \\return gl.getAttribLocation(glPrograms[program_id], name);
    },
    // TODO - glGetBufferParameter
    // TODO - glGetContextAttributes
    Func {
        .name = "glGetError",
        .args = &[_]Arg {},
        .ret = "c_int",
        .js =
            \\return gl.getError();
    },
    // TODO - glGetExtension
    // TODO - glGetFramebufferAttachmentParameter
    // TODO - glGetParameter
    // TODO - glGetProgramInfoLog
    // TODO - glGetProgramParameter
    // TODO - glGetRenderbufferParameter
    // TODO - glGetShaderInfoLog
    // TODO - glGetShaderParameter
    // TODO - glGetShaderPrecisionFormat
    // TODO - glGetShaderSource
    // TODO - glGetSupportedExtensions
    // TODO - glGetTexParameter
    // TODO - glGetUniform
    Func {
        .name = "glGetUniformLocation",
        .args = &[_]Arg {
            .{ .name = "program_id", .type = "c_uint" },
            .{ .name = "name", .type = "SLICE" },
        },
        .ret = "c_int",
        .js =
            \\glUniformLocations.push(gl.getUniformLocation(glPrograms[program_id], name));
            \\return glUniformLocations.length - 1;
    },
    // TODO - glGetVertexAttrib
    // TODO - glGetVertexAttribOffset
    // TODO - glHint
    // TODO - glIsBuffer
    // TODO - glIsContextLost
    // TODO - glIsEnabled
    // TODO - glIsFramebuffer
    // TODO - glIsProgram
    // TODO - glIsRenderbuffer
    // TODO - glIsShader
    // TODO - glIsTexture
    // TODO - glLineWidth
    Func {
        .name = "glLinkProgram",
        .args = &[_]Arg {
            .{ .name = "program", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            // TODO - don't call getProgramParameter here
            \\gl.linkProgram(glPrograms[program]);
            \\if (!gl.getProgramParameter(glPrograms[program], gl.LINK_STATUS)) {
            \\    throw ("Error linking program:" + gl.getProgramInfoLog(glPrograms[program]));
            \\}
    },
    Func {
        .name = "glPixelStorei",
        .args = &[_]Arg {
            .{ .name = "pname", .type = "GLenum" },
            .{ .name = "param", .type = "GLint" },
        },
        .ret = "void",
        .js =
            \\gl.pixelStorei(pname, param);
    },
    // TODO - glPolygonOffset
    // TODO - glReadPixels
    // TODO - glRenderbufferStorage
    // TODO - glSampleCoverage
    // TODO - glScissor
    Func {
        .name = "glShaderSource",
        .args = &[_]Arg {
            .{ .name = "shader", .type = "GLuint" },
            .{ .name = "string", .type = "SLICE" },
        },
        .ret = "void",
        .js =
            \\gl.shaderSource(glShaders[shader], string);
    },
    // TODO - glStencilFunc
    // TODO - glStencilFuncSeparate
    // TODO - glStencilMask
    // TODO - glStencilMaskSeparate
    // TODO - glStencilOp
    // TODO - glStencilOpSeparate
    Func {
        .name = "glTexImage2D",
        // FIXME - take slice for data. note it needs to be optional
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
            .{ .name = "level", .type = "c_uint" },
            .{ .name = "internal_format", .type = "c_uint" },
            .{ .name = "width", .type = "c_int" },
            .{ .name = "height", .type = "c_int" },
            .{ .name = "border", .type = "c_uint" },
            .{ .name = "format", .type = "c_uint" },
            .{ .name = "type", .type = "c_uint" },
            .{ .name = "data_ptr", .type = "?[*]const u8" },
            .{ .name = "data_len", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\// FIXME - look at data_ptr, not data_len, to determine NULL?
            \\const data = data_len > 0 ? new Uint8Array(getMemory().buffer, data_ptr, data_len) : null;
            \\gl.texImage2D(target, level, internal_format, width, height, border, format, type, data);
    },
    Func {
        .name = "glTexParameterf",
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
            .{ .name = "pname", .type = "c_uint" },
            .{ .name = "param", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.texParameterf(target, pname, param);
    },
    Func {
        .name = "glTexParameteri",
        .args = &[_]Arg {
            .{ .name = "target", .type = "c_uint" },
            .{ .name = "pname", .type = "c_uint" },
            .{ .name = "param", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.texParameteri(target, pname, param);
    },
    // TODO - glTexSubImage2D
    Func {
        .name = "glUniform1f",
        .args = &[_]Arg {
            .{ .name = "location_id", .type = "c_int" },
            .{ .name = "x", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.uniform1f(glUniformLocations[location_id], x);
    },
    // TODO - glUniform1fv
    Func {
        .name = "glUniform1i",
        .args = &[_]Arg {
            .{ .name = "location_id", .type = "c_int" },
            .{ .name = "x", .type = "c_int" },
        },
        .ret = "void",
        .js =
            \\gl.uniform1i(glUniformLocations[location_id], x);
    },
    // TODO - glUniform1iv
    // TODO - glUniform2f
    // TODO - glUniform2fv
    // TODO - glUniform2i
    // TODO - glUniform2iv
    // TODO - glUniform3f
    // TODO - glUniform3fv
    // TODO - glUniform3i
    // TODO - glUniform3iv
    Func {
        .name = "glUniform4f",
        .args = &[_]Arg {
            .{ .name = "location_id", .type = "c_int" },
            .{ .name = "x", .type = "f32" },
            .{ .name = "y", .type = "f32" },
            .{ .name = "z", .type = "f32" },
            .{ .name = "w", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.uniform4f(glUniformLocations[location_id], x, y, z, w);
    },
    // TODO - glUniform4fv
    // TODO - glUniform4i
    // TODO - glUniform4iv
    // TODO - glUniformMatrix2fv
    // TODO - glUniformMatrix3fv
    Func {
        .name = "glUniformMatrix4fv",
        // FIXME - take three args, not four.. transpose should be second arg
        .args = &[_]Arg {
            .{ .name = "location_id", .type = "c_int" },
            .{ .name = "data_len", .type = "c_int" },
            .{ .name = "transpose", .type = "c_uint" },
            .{ .name = "data_ptr", .type = "[*]const f32" },
        },
        .ret = "void",
        .js =
            \\const floats = new Float32Array(getMemory().buffer, data_ptr, data_len * 16);
            \\gl.uniformMatrix4fv(glUniformLocations[location_id], transpose, floats);
    },
    Func {
        .name = "glUseProgram",
        .args = &[_]Arg {
            .{ .name = "program_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.useProgram(glPrograms[program_id]);
    },
    // TODO - glValidateProgram
    // TODO - glVertexAttrib1f
    // TODO - glVertexAttrib1fv
    // TODO - glVertexAttrib2f
    // TODO - glVertexAttrib2fv
    // TODO - glVertexAttrib3f
    // TODO - glVertexAttrib3fv
    // TODO - glVertexAttrib4f
    // TODO - glVertexAttrib4fv
    Func {
        .name = "glVertexAttribPointer",
        .args = &[_]Arg {
            .{ .name = "attrib_location", .type = "c_uint" },
            .{ .name = "size", .type = "c_uint" },
            .{ .name = "type", .type = "c_uint" },
            .{ .name = "normalize", .type = "c_uint" },
            .{ .name = "stride", .type = "c_uint" },
            .{ .name = "offset", .type = "[*c]const c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.vertexAttribPointer(attrib_location, size, type, normalize, stride, offset);
    },
    Func {
        .name = "glViewport",
        .args = &[_]Arg {
            .{ .name = "x", .type = "c_int" },
            .{ .name = "y", .type = "c_int" },
            .{ .name = "width", .type = "c_int" },
            .{ .name = "height", .type = "c_int" },
        },
        .ret = "void",
        .js =
            \\gl.viewport(x, y, width, height);
    },
};

fn nextNewline(s: []const u8) usize {
    for (s) |ch, i| {
        if (ch == '\n') {
            return i;
        }
    }
    return s.len;
}

fn writeZigFile(filename: []const u8) !void {
    const file = try std.fs.File.openWrite(filename);
    defer file.close();

    var stream = &std.fs.File.outStream(file).stream;

    try stream.print("{}\n\n", .{zig_top});

    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        try stream.print("{}extern fn {}{}(", [_][]const u8 {
            if (any_slice) "" else "pub ",
            func.name,
            if (any_slice) "_" else "",
        });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr: [*]const u8, {}_len: c_uint", .{arg.name, arg.name});
            } else {
                try stream.print("{}: {}", .{arg.name, arg.type});
            }
        }
        try stream.print(") {};\n", .{func.ret});

        if (any_slice) {
            try stream.print("pub fn {}(", .{func.name});
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}: []const u8", .{arg.name});
                } else {
                    try stream.print("{}: {}", .{arg.name, arg.type});
                }
            }
            try stream.print(") {} {{\n", .{func.ret});
            try stream.print("    {}{}_(", [_][]const u8 {
                if (std.mem.eql(u8, func.ret, "void")) "" else "return ",
                func.name,
            });
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ", .{});
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}.ptr, {}.len", .{arg.name, arg.name});
                } else {
                    try stream.print("{}", .{arg.name});
                }
            }
            try stream.print(");\n", .{});
            try stream.print("}}\n", .{});
        }
    }
}

fn writeJsFile(filename: []const u8) !void {
    const file = try std.fs.File.openWrite(filename);
    defer file.close();

    var stream = &std.fs.File.outStream(file).stream;

    try stream.print("{}\n", .{js_top});

    try stream.print("    return {{\n", .{});
    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        try stream.print("        {}{}(", [_][]const u8 {
            func.name,
            if (any_slice) "_" else "",
        });
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ", .{});
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr, {}_len", .{arg.name, arg.name});
            } else {
                try stream.print("{}", .{arg.name});
            }
        }
        try stream.print(") {{\n", .{});
        for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("            const {} = readCharStr({}_ptr, {}_len);\n", .{arg.name, arg.name, arg.name});
            }
        }
        var start: usize = 0; while (start < func.js.len) {
            const rel_newline_pos = nextNewline(func.js[start..]);
            try stream.print("            {}\n", .{func.js[start..start + rel_newline_pos]});
            start += rel_newline_pos + 1;
        }
        try stream.print("        }},\n", .{});
    }
    try stream.print("    }};\n", .{});

    try stream.print("{}\n", .{js_bottom});
}

pub fn main() !void {
    try writeZigFile("src/web/webgl_generated.zig");
    try writeJsFile("js/oxid_webgl.js");
}
