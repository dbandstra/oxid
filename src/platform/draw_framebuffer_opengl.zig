// this is an optional feature that can be used on top of draw_opengl.zig.
// requires either OpenGL 3+ or GL_ARB_framebuffer_object.
// this allows you to draw to an off-screen framebuffer, then scale it up to
// fit the window for a pixellated look. note: web builds do not need this
// because they can just scale up the DOM canvas.

usingnamespace @import("gl").namespace;
const pdraw = @import("draw_opengl.zig");
const draw = @import("../common/draw.zig");

pub const BlitRect = struct {
    x: i32,
    y: i32,
    w: u31,
    h: u31,
};

pub const FramebufferState = struct {
    framebuffer: GLuint,
    render_texture: GLuint,
};

pub fn init(fbs: *FramebufferState, w: u31, h: u31) bool {
    var fb: GLuint = 0;
    var rt: GLuint = 0;

    glGenFramebuffers(1, &fb);
    glBindFramebuffer(GL_FRAMEBUFFER, fb);

    glGenTextures(1, &rt);
    glBindTexture(GL_TEXTURE_2D, rt);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, w, h, 0, GL_RGB, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt, 0);

    var draw_buffers = [_]GLenum{
        GL_COLOR_ATTACHMENT0,
    };
    glDrawBuffers(1, &draw_buffers[0]);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
        return false;
    }

    fbs.framebuffer = fb;
    fbs.render_texture = rt;
    return true;
}

pub fn deinit(fbs: *FramebufferState) void {
    glDeleteTextures(1, &fbs.render_texture);
    glDeleteFramebuffers(1, &fbs.framebuffer);
}

pub fn preDraw(fbs: *FramebufferState) void {
    glBindFramebuffer(GL_FRAMEBUFFER, fbs.framebuffer);
}

pub fn postDraw(fbs: *FramebufferState, ds: *pdraw.State, blit_rect: BlitRect, blit_alpha: f32) void {
    pdraw.flush(ds);

    // blit renderbuffer to screen
    ds.projection = pdraw.ortho(0, 1, 1, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(blit_rect.x, blit_rect.y, blit_rect.w, blit_rect.h);

    ds.draw_buffer.vertex2f[0..12].* = .{ 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0 };
    ds.draw_buffer.texcoord2f[0..12].* = .{ 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1 };

    ds.shader_textured.bind(.{
        .tex = 0,
        .color = .{ .r = 1, .g = 1, .b = 1, .a = blit_alpha },
        .mvp = &ds.projection,
        .vertex_buffer = ds.dyn_vertex_buffer,
        .vertex2f = &ds.draw_buffer.vertex2f,
        .texcoord_buffer = ds.dyn_texcoord_buffer,
        .texcoord2f = &ds.draw_buffer.texcoord2f,
    });

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, fbs.render_texture);

    glDrawArrays(GL_TRIANGLES, 0, 6);
}
