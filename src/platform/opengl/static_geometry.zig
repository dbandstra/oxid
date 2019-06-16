usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
});

const std = @import("std");

pub const BUFFER_VERTICES = 4*512; // render up to 512 quads at once

pub const StaticGeometry = struct{
    rect_2d_vertex_buffer: GLuint,
    rect_2d_blit_texcoord_buffer: GLuint,

    dyn_vertex_buffer: GLuint,
    dyn_texcoord_buffer: GLuint,

    pub fn destroy(sg: *StaticGeometry) void {
        glDeleteBuffers(1, &sg.rect_2d_vertex_buffer);
        glDeleteBuffers(1, &sg.rect_2d_blit_texcoord_buffer);
        glDeleteBuffers(1, &sg.dyn_vertex_buffer);
        glDeleteBuffers(1, &sg.dyn_texcoord_buffer);
    }
};

pub fn updateVbo(vbo: GLuint, maybe_data2f: ?[]f32) void {
    const size = BUFFER_VERTICES * 2 * @sizeOf(GLfloat);
    const null_data = @intToPtr(?*const c_void, 0);

    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, size, null_data, GL_STREAM_DRAW);
    if (maybe_data2f) |data2f| {
        std.debug.assert(data2f.len == 2 * BUFFER_VERTICES);
        glBufferData(GL_ARRAY_BUFFER, size, &data2f[0], GL_STREAM_DRAW);
    }
}

pub fn createStaticGeometry() StaticGeometry {
    var sg: StaticGeometry = undefined;

    glGenBuffers(1, &sg.dyn_vertex_buffer);
    updateVbo(sg.dyn_vertex_buffer, null);
    glGenBuffers(1, &sg.dyn_texcoord_buffer);
    updateVbo(sg.dyn_texcoord_buffer, null);

    const rect_2d_vertexes = [_][2]GLfloat{
        [_]GLfloat{ 0.0, 0.0 },
        [_]GLfloat{ 0.0, 1.0 },
        [_]GLfloat{ 1.0, 0.0 },
        [_]GLfloat{ 1.0, 1.0 },
    };
    glGenBuffers(1, &sg.rect_2d_vertex_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, sg.rect_2d_vertex_buffer);
    glBufferData(GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(GLfloat), &rect_2d_vertexes[0][0], GL_STATIC_DRAW);

    const rect_2d_blit_texcoords = [_][2]GLfloat{
        [_]GLfloat{ 0.0, 1.0 },
        [_]GLfloat{ 0.0, 0.0 },
        [_]GLfloat{ 1.0, 1.0 },
        [_]GLfloat{ 1.0, 0.0 },
    };
    glGenBuffers(1, &sg.rect_2d_blit_texcoord_buffer);
    glBindBuffer(GL_ARRAY_BUFFER, sg.rect_2d_blit_texcoord_buffer);
    glBufferData(GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(GLfloat), &rect_2d_blit_texcoords, GL_STATIC_DRAW);

    return sg;
}
