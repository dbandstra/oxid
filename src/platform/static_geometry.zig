const c = @import("c.zig");

pub const StaticGeometry = struct {
    rect_2d_vertex_buffer: c.GLuint,
    rect_2d_tex_coord_buffer_normal: c.GLuint,
    rect_2d_tex_coord_buffer_flip_vertical: c.GLuint,
    rect_2d_tex_coord_buffer_flip_horizontal: c.GLuint,
    rect_2d_tex_coord_buffer_rotate_clockwise: c.GLuint,
    rect_2d_tex_coord_buffer_rotate_counter_clockwise: c.GLuint,

    triangle_2d_vertex_buffer: c.GLuint,
    triangle_2d_tex_coord_buffer: c.GLuint,

    pub fn destroy(sg: *StaticGeometry) void {
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_vertex_buffer));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_normal));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_flip_vertical));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_flip_horizontal));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_rotate_clockwise));
        c.glDeleteBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_rotate_counter_clockwise));

        c.glDeleteBuffers(1, c.ptr(&sg.triangle_2d_vertex_buffer));
        c.glDeleteBuffers(1, c.ptr(&sg.triangle_2d_tex_coord_buffer));
    }
};

pub fn createStaticGeometry() StaticGeometry {
    var sg: StaticGeometry = undefined;

    const rect_2d_vertexes = [][3]c.GLfloat{
        []c.GLfloat{ 0.0, 0.0, 0.0 },
        []c.GLfloat{ 0.0, 1.0, 0.0 },
        []c.GLfloat{ 1.0, 0.0, 0.0 },
        []c.GLfloat{ 1.0, 1.0, 0.0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_vertex_buffer));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_vertex_buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 3 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_vertexes[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_tex_coords_normal = [][2]c.GLfloat{
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 0, 1 },
        []c.GLfloat{ 1, 0 },
        []c.GLfloat{ 1, 1 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_normal));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_tex_coord_buffer_normal);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_tex_coords_normal[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_tex_coords_flip_vertical = [][2]c.GLfloat{
        []c.GLfloat{ 0, 1 },
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 1, 1 },
        []c.GLfloat{ 1, 0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_flip_vertical));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_tex_coord_buffer_flip_vertical);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_tex_coords_flip_vertical[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_tex_coords_flip_horizontal = [][2]c.GLfloat{
        []c.GLfloat{ 1, 0 },
        []c.GLfloat{ 1, 1 },
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 0, 1 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_flip_horizontal));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_tex_coord_buffer_flip_horizontal);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_tex_coords_flip_horizontal[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_tex_coords_rotate_clockwise = [][2]c.GLfloat{
        []c.GLfloat{ 0, 1 },
        []c.GLfloat{ 1, 1 },
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 1, 0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_rotate_clockwise));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_tex_coord_buffer_rotate_clockwise);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_tex_coords_rotate_clockwise[0][0]), c.GL_STATIC_DRAW);

    const rect_2d_tex_coords_rotate_counter_clockwise = [][2]c.GLfloat{
        []c.GLfloat{ 1, 0 },
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 1, 1 },
        []c.GLfloat{ 0, 1 },
    };
    c.glGenBuffers(1, c.ptr(&sg.rect_2d_tex_coord_buffer_rotate_counter_clockwise));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.rect_2d_tex_coord_buffer_rotate_counter_clockwise);
    c.glBufferData(c.GL_ARRAY_BUFFER, 4 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &rect_2d_tex_coords_rotate_counter_clockwise[0][0]), c.GL_STATIC_DRAW);

    const triangle_2d_vertexes = [][3]c.GLfloat{
        []c.GLfloat{ 0.0, 0.0, 0.0 },
        []c.GLfloat{ 0.0, 1.0, 0.0 },
        []c.GLfloat{ 1.0, 0.0, 0.0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.triangle_2d_vertex_buffer));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.triangle_2d_vertex_buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 3 * 3 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &triangle_2d_vertexes[0][0]), c.GL_STATIC_DRAW);

    const triangle_2d_tex_coords = [][2]c.GLfloat{
        []c.GLfloat{ 0, 0 },
        []c.GLfloat{ 0, 1 },
        []c.GLfloat{ 1, 0 },
    };
    c.glGenBuffers(1, c.ptr(&sg.triangle_2d_tex_coord_buffer));
    c.glBindBuffer(c.GL_ARRAY_BUFFER, sg.triangle_2d_tex_coord_buffer);
    c.glBufferData(c.GL_ARRAY_BUFFER, 3 * 2 * @sizeOf(c.GLfloat), @ptrCast(*const c_void, &triangle_2d_tex_coords[0][0]), c.GL_STATIC_DRAW);

    return sg;
}
