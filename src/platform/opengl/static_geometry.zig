const std = @import("std");
const c = @import("../c.zig");

pub const BUFFER_VERTICES = 4*512; // render up to 512 quads at once

pub const StaticGeometry = struct.{
    rect_2d_vertex_buffer: c.GLuint,
    rect_2d_blit_texcoord_buffer: c.GLuint,

    dyn_vertex_buffer: c.GLuint,
    dyn_texcoord_buffer: c.GLuint,

    pub fn destroy(sg: *StaticGeometry) void {
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_vertex_buffer));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_blit_texcoord_buffer));
        c.glDeleteBuffers(1, c.ptr(&sg.dyn_vertex_buffer));
        c.glDeleteBuffers(1, c.ptr(&sg.dyn_texcoord_buffer));
    }
};

pub fn updateVbo(vbo: c.GLuint, maybe_data2f: ?[]f32) void {
    const size = BUFFER_VERTICES * 2 * @sizeOf(c.GLfloat);
    const null_data = @intToPtr(*const c_void, 0);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, size, null_data, c.GL_STREAM_DRAW);
    if (maybe_data2f) |data2f| {
        std.debug.assert(data2f.len == 2 * BUFFER_VERTICES);
        const data = @ptrCast(*const c_void, &data2f[0]);
        c.glBufferData(c.GL_ARRAY_BUFFER, size, data, c.GL_STREAM_DRAW);
    }
}

pub fn createStaticGeometry() StaticGeometry {
    var sg: StaticGeometry = undefined;

    c.glGenBuffers(1, c.ptr(&sg.dyn_vertex_buffer));
    updateVbo(sg.dyn_vertex_buffer, null);
    c.glGenBuffers(1, c.ptr(&sg.dyn_texcoord_buffer));
    updateVbo(sg.dyn_texcoord_buffer, null);

    const rect_2d_vertexes = [][2]c.GLfloat.{
        []c.GLfloat.{ 0.0, 0.0 },
        []c.GLfloat.{ 0.0, 1.0 },
        []c.GLfloat.{ 1.0, 0.0 },
        []c.GLfloat.{ 1.0, 1.0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_vertex_buffer));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_vertex_buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_vertexes[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_blit_texcoords = [][2]c.GLfloat.{
        []c.GLfloat.{ 0.0, 1.0 },
        []c.GLfloat.{ 0.0, 0.0 },
        []c.GLfloat.{ 1.0, 1.0 },
        []c.GLfloat.{ 1.0, 0.0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_blit_texcoord_buffer));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_blit_texcoord_buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_blit_texcoords[0][0]), c.GL_STATIC_DRAW);

    return sg;
}
