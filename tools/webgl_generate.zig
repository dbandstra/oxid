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

// FIXME - js function bodies assumes `memory` exists at global scope
// would rather be more explicit about this?

const js_top =
    \\const readCharStr = (ptr, len) => {
    \\    const bytes = new Uint8Array(memory.buffer, ptr, len);
    \\    let s = "";
    \\    for (let i = 0; i < len; ++i) {
    \\        s += String.fromCharCode(bytes[i]);
    \\    }
    \\    return s;
    \\};
    \\
    \\const glShaders = [];
    \\const glPrograms = [];
    \\const glVertexArrays = [];
    \\const glBuffers = [];
    \\const glTextures = [];
    \\const glFramebuffers = [];
    \\const glUniformLocations = [];
;

const funcs = [_]Func {
    Func {
        .name = "glActiveTexture",
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.activeTexture(target);
    },
    Func {
        .name = "glAttachShader",
        .args = [_]Arg {
            Arg { .name = "program", .type = "c_uint" },
            Arg { .name = "shader", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.attachShader(glPrograms[program], glShaders[shader]);
    },
    Func {
        .name = "glBindBuffer",
        .args = [_]Arg {
            Arg { .name = "type", .type = "c_uint" },
            Arg { .name = "buffer_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindBuffer(type, glBuffers[buffer_id]);
    },
    Func {
        .name = "glBindFramebuffer",
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
            Arg { .name = "framebuffer", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindFramebuffer(target, glFramebuffers[framebuffer]);
    },
    Func {
        .name = "glBindTexture",
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
            Arg { .name = "texture_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindTexture(target, glTextures[texture_id]);
    },
    Func {
        .name = "glBindVertexArray",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.bindVertexArray(glVertexArrays[id]);
    },
    Func {
        .name = "glBlendFunc",
        .args = [_]Arg {
            Arg { .name = "x", .type = "c_uint" },
            Arg { .name = "y", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.blendFunc(x, y);
    },
    Func {
        .name = "glBufferData",
        .args = [_]Arg {
            Arg { .name = "type", .type = "c_uint" },
            Arg { .name = "count", .type = "c_uint" },
            Arg { .name = "data_ptr", .type = "[*c]const f32" },
            Arg { .name = "draw_type", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\// TODO - check for NULL?
            \\const floats = new Float32Array(memory.buffer, data_ptr, count);
            \\gl.bufferData(type, floats, draw_type);
    },
    Func {
        .name = "glCheckFramebufferStatus",
        .args = [_]Arg {
            Arg { .name = "target", .type = "GLenum" },
        },
        .ret = "GLenum",
        .js =
            \\return gl.checkFramebufferStatus(target);
    },
    Func {
        .name = "glClear",
        .args = [_]Arg {
            Arg { .name = "mask", .type = "GLbitfield" },
        },
        .ret = "void",
        .js =
            \\gl.clear(mask);
    },
    Func {
        .name = "glClearColor",
        .args = [_]Arg {
            Arg { .name = "r", .type = "f32" },
            Arg { .name = "g", .type = "f32" },
            Arg { .name = "b", .type = "f32" },
            Arg { .name = "a", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.clearColor(r, g, b, a);
    },
    Func {
        .name = "glCompileShader",
        .args = [_]Arg {
            Arg { .name = "shader", .type = "GLuint" },
        },
        .ret = "void",
        .js =
            // TODO don't call getShaderParameter here
            \\gl.compileShader(glShaders[shader]);
            \\if (!gl.getShaderParameter(glShaders[shader], gl.COMPILE_STATUS)) {
            \\    throw "Error compiling shader:" + gl.getShaderInfoLog(glShaders[shader]);
            \\}
    },
    Func {
        .name = "glCreateBuffer",
        .args = [_]Arg {},
        .ret = "c_uint",
        .js =
            \\glBuffers.push(gl.createBuffer());
            \\return glBuffers.length - 1;
    },
    Func {
        .name = "glCreateFramebuffer",
        .args = [_]Arg {},
        .ret = "GLuint",
        .js =
            \\glFramebuffers.push(gl.createFramebuffer());
            \\return glFramebuffers.length - 1;
    },
    Func {
        .name = "glCreateProgram",
        .args = [_]Arg {},
        .ret = "GLuint",
        .js =
            \\glPrograms.push(gl.createProgram());
            \\return glPrograms.length - 1;
    },
    Func {
        .name = "glCreateShader",
        .args = [_]Arg {
            Arg { .name = "shader_type", .type = "GLenum" },
        },
        .ret = "GLuint",
        .js =
            \\glShaders.push(gl.createShader(shader_type));
            \\return glShaders.length - 1;
    },
    Func {
        .name = "glCreateTexture",
        .args = [_]Arg {},
        .ret = "c_uint",
        .js =
            \\glTextures.push(gl.createTexture());
            \\return glTextures.length - 1;
    },
    Func {
        .name = "glCreateVertexArray",
        .args = [_]Arg {},
        .ret = "c_uint",
        .js =
            \\glVertexArrays.push(gl.createVertexArray());
            \\return glVertexArrays.length - 1;
    },
    Func {
        .name = "glDeleteBuffer",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteBuffer(glBuffers[id]);
            \\glBuffers[id] = undefined;
    },
    Func {
        .name = "glDeleteShader",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteShader(glShaders[id]);
            \\glShaders[id] = undefined;
    },
    Func {
        .name = "glDeleteProgram",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteProgram(glPrograms[id]);
            \\glPrograms[id] = undefined;
    },
    Func {
        .name = "glDeleteTexture",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteTexture(glTextures[id]);
            \\glTextures[id] = undefined;
    },
    Func {
        .name = "glDeleteVertexArray",
        .args = [_]Arg {
            Arg { .name = "id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.deleteVertexArray(glVertexArrays[id]);
            \\glVertexArrays[id] = undefined;
    },
    Func {
        .name = "glDepthFunc",
        .args = [_]Arg {
            Arg { .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.depthFunc(x);
    },
    Func {
        .name = "glDetachShader",
        .args = [_]Arg {
            Arg { .name = "program", .type = "c_uint" },
            Arg { .name = "shader", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.detachShader(glPrograms[program], glShaders[shader]);
    },
    Func {
        .name = "glDisable",
        .args = [_]Arg {
            Arg { .name = "cap", .type = "GLenum" },
        },
        .ret = "void",
        .js =
            \\gl.disable(cap);
    },
    Func {
        .name = "glDrawArrays",
        .args = [_]Arg {
            Arg { .name = "type", .type = "c_uint" },
            Arg { .name = "offset", .type = "c_uint" },
            Arg { .name = "count", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.drawArrays(type, offset, count);
    },
    Func {
        .name = "glDrawBuffers",
        .args = [_]Arg {
            // FIXME
            Arg { .name = "num", .type = "GLsizei" },
            Arg { .name = "bufs", .type = "[*c]const GLenum" },
        },
        .ret = "void",
        .js =
            \\gl.drawBuffers(new Uint32Array(memory.buffer, bufs, num));
    },
    Func {
        .name = "glEnable",
        .args = [_]Arg {
            Arg { .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.enable(x);
    },
    Func {
        .name = "glEnableVertexAttribArray",
        .args = [_]Arg {
            Arg { .name = "x", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.enableVertexAttribArray(x);
    },
    Func {
        .name = "glFramebufferTexture2D",
        .args = [_]Arg {
            Arg { .name = "target", .type = "GLenum" },
            Arg { .name = "attachment", .type = "GLenum" },
            Arg { .name = "textarget", .type = "GLenum" },
            Arg { .name = "texture", .type = "GLuint" },
            Arg { .name = "level", .type = "GLint" },
        },
        .ret = "void",
        .js =
            \\gl.framebufferTexture2D(target, attachment, textarget, glTextures[texture], level);
    },
    Func {
        .name = "glFrontFace",
        .args = [_]Arg {
            Arg { .name = "mode", .type = "GLenum" },
        },
        .ret = "void",
        .js =
            \\gl.frontFace(mode);
    },
    Func {
        .name = "glGetAttribLocation",
        .args = [_]Arg {
            Arg { .name = "program_id", .type = "c_uint" },
            Arg { .name = "name", .type = "SLICE" },
        },
        .ret = "c_int",
        .js =
            \\return gl.getAttribLocation(glPrograms[program_id], name);
    },
    Func {
        .name = "glGetError",
        .args = [_]Arg {},
        .ret = "c_int",
        .js =
            \\return gl.getError();
    },
    Func {
        .name = "glGetUniformLocation",
        .args = [_]Arg {
            Arg { .name = "program_id", .type = "c_uint" },
            Arg { .name = "name", .type = "SLICE" },
        },
        .ret = "c_int",
        .js =
            \\glUniformLocations.push(gl.getUniformLocation(glPrograms[program_id], name));
            \\return glUniformLocations.length - 1;
    },
    Func {
        .name = "glLinkProgram",
        .args = [_]Arg {
            Arg { .name = "program", .type = "c_uint" },
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
        .args = [_]Arg {
            Arg { .name = "pname", .type = "GLenum" },
            Arg { .name = "param", .type = "GLint" },
        },
        .ret = "void",
        .js =
            \\gl.pixelStorei(pname, param);
    },
    Func {
        .name = "glShaderSource",
        .args = [_]Arg {
            Arg { .name = "shader", .type = "GLuint" },
            Arg { .name = "string", .type = "SLICE" },
        },
        .ret = "void",
        .js =
            \\console.log('shader source', string);
            \\gl.shaderSource(glShaders[shader], string);
    },
    Func {
        .name = "glTexImage2D",
        // FIXME - take slice for data. note it needs to be optional
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
            Arg { .name = "level", .type = "c_uint" },
            Arg { .name = "internal_format", .type = "c_uint" },
            Arg { .name = "width", .type = "c_int" },
            Arg { .name = "height", .type = "c_int" },
            Arg { .name = "border", .type = "c_uint" },
            Arg { .name = "format", .type = "c_uint" },
            Arg { .name = "type", .type = "c_uint" },
            Arg { .name = "data_ptr", .type = "?[*]const u8" },
            Arg { .name = "data_len", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\// FIXME - look at data_ptr, not data_len, to determine NULL?
            \\const data = data_len > 0 ? new Uint8Array(memory.buffer, data_ptr, data_len) : null;
            \\gl.texImage2D(target, level, internal_format, width, height, border, format, type, data);
    },
    Func {
        .name = "glTexParameterf",
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
            Arg { .name = "pname", .type = "c_uint" },
            Arg { .name = "param", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.texParameterf(target, pname, param);
    },
    Func {
        .name = "glTexParameteri",
        .args = [_]Arg {
            Arg { .name = "target", .type = "c_uint" },
            Arg { .name = "pname", .type = "c_uint" },
            Arg { .name = "param", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.texParameteri(target, pname, param);
    },
    Func {
        .name = "glUniform1f",
        .args = [_]Arg {
            Arg { .name = "location_id", .type = "c_int" },
            Arg { .name = "x", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.uniform1f(glUniformLocations[location_id], x);
    },
    Func {
        .name = "glUniform1i",
        .args = [_]Arg {
            Arg { .name = "location_id", .type = "c_int" },
            Arg { .name = "x", .type = "c_int" },
        },
        .ret = "void",
        .js =
            \\gl.uniform1i(glUniformLocations[location_id], x);
    },
    Func {
        .name = "glUniform4f",
        .args = [_]Arg {
            Arg { .name = "location_id", .type = "c_int" },
            Arg { .name = "x", .type = "f32" },
            Arg { .name = "y", .type = "f32" },
            Arg { .name = "z", .type = "f32" },
            Arg { .name = "w", .type = "f32" },
        },
        .ret = "void",
        .js =
            \\gl.uniform4f(glUniformLocations[location_id], x, y, z, w);
    },
    Func {
        .name = "glUniformMatrix4fv",
        // FIXME - take three args, not four.. transpose should be second arg
        .args = [_]Arg {
            Arg { .name = "location_id", .type = "c_int" },
            Arg { .name = "data_len", .type = "c_int" },
            Arg { .name = "transpose", .type = "c_uint" },
            Arg { .name = "data_ptr", .type = "[*]const f32" },
        },
        .ret = "void",
        .js =
            \\const floats = new Float32Array(memory.buffer, data_ptr, data_len * 16);
            \\gl.uniformMatrix4fv(glUniformLocations[location_id], transpose, floats);
    },
    Func {
        .name = "glUseProgram",
        .args = [_]Arg {
            Arg { .name = "program_id", .type = "c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.useProgram(glPrograms[program_id]);
    },
    Func {
        .name = "glVertexAttribPointer",
        .args = [_]Arg {
            Arg { .name = "attrib_location", .type = "c_uint" },
            Arg { .name = "size", .type = "c_uint" },
            Arg { .name = "type", .type = "c_uint" },
            Arg { .name = "normalize", .type = "c_uint" },
            Arg { .name = "stride", .type = "c_uint" },
            Arg { .name = "offset", .type = "[*c]const c_uint" },
        },
        .ret = "void",
        .js =
            \\gl.vertexAttribPointer(attrib_location, size, type, normalize, stride, offset);
    },
    Func {
        .name = "glViewport",
        .args = [_]Arg {
            Arg { .name = "x", .type = "c_int" },
            Arg { .name = "y", .type = "c_int" },
            Arg { .name = "width", .type = "c_int" },
            Arg { .name = "height", .type = "c_int" },
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

    try stream.print("{}\n\n", zig_top);

    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        try stream.print("{}extern fn {}{}(", if (any_slice) "" else "pub ", func.name, if (any_slice) "_" else "");
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ");
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr: [*]const u8, {}_len: c_uint", arg.name, arg.name);
            } else {
                try stream.print("{}: {}", arg.name, arg.type);
            }
        }
        try stream.print(") {};\n", func.ret);

        if (any_slice) {
            try stream.print("pub fn {}(", func.name);
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ");
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}: []const u8", arg.name);
                } else {
                    try stream.print("{}: {}", arg.name, arg.type);
                }
            }
            try stream.print(") {} {{\n", func.ret);
            try stream.print("    {}{}_(", if (std.mem.eql(u8, func.ret, "void")) "" else "return ", func.name);
            for (func.args) |arg, i| {
                if (i > 0) {
                    try stream.print(", ");
                }
                if (std.mem.eql(u8, arg.type, "SLICE")) {
                    try stream.print("{}.ptr, {}.len", arg.name, arg.name);
                } else {
                    try stream.print("{}", arg.name);
                }
            }
            try stream.print(");\n");
            try stream.print("}}\n");
        }
    }
}

fn writeJsFile(filename: []const u8) !void {
    const file = try std.fs.File.openWrite(filename);
    defer file.close();

    var stream = &std.fs.File.outStream(file).stream;

    try stream.print("{}\n\n", js_top);

    try stream.print("const webgl = {{\n");
    for (funcs) |func| {
        const any_slice = for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                break true;
            }
        } else false;

        try stream.print("    {}{}(", func.name, if (any_slice) "_" else "");
        for (func.args) |arg, i| {
            if (i > 0) {
                try stream.print(", ");
            }
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("{}_ptr, {}_len", arg.name, arg.name);
            } else {
                try stream.print("{}", arg.name);
            }
        }
        try stream.print(") {{\n");
        for (func.args) |arg| {
            if (std.mem.eql(u8, arg.type, "SLICE")) {
                try stream.print("        const {} = readCharStr({}_ptr, {}_len);\n", arg.name, arg.name, arg.name);
            }
        }
        var start: usize = 0; while (start < func.js.len) {
            const rel_newline_pos = nextNewline(func.js[start..]);
            try stream.print("        {}\n", func.js[start..start + rel_newline_pos]);
            start += rel_newline_pos + 1;
        }
        try stream.print("    }},\n");
    }
    try stream.print("}};\n");
}

pub fn main() !void {
    try writeZigFile("src/web/webgl_generated.zig");
    try writeJsFile("js/webgl_generated.js");
}
