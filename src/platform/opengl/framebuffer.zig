// this is an optional feature that can be used on top of draw.zig
// the wasm build doesn't use it because it can just scale up the DOM canvas

const builtin = @import("builtin");
usingnamespace
    if (builtin.arch == .wasm32)
        @import("../../web.zig")
    else
        @cImport({
            @cInclude("epoxy/gl.h");
        });
const pdraw = @import("draw.zig");
const draw = @import("../../common/draw.zig");

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

    if (builtin.arch == .wasm32) {
        fb = glCreateFramebuffer();
    } else {
        glGenFramebuffers(1, &fb);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, fb);

    glGenTextures(1, &rt);
    glBindTexture(GL_TEXTURE_2D, rt);
    if (builtin.arch == .wasm32) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, c_int(w), c_int(h), 0, GL_RGB, GL_UNSIGNED_BYTE, @intToPtr(?[*]const u8, 0), 0);
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, c_int(w), c_int(h), 0, GL_RGB, GL_UNSIGNED_BYTE, @intToPtr(?*const c_void, 0));
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, rt, 0);

    var draw_buffers = [_]GLenum {
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
    if (builtin.arch == .wasm32) {
        glDeleteTexture(GL_TEXTURE_2D, fbs.render_texture);
        glDeleteFramebuffer(GL_FRAMEBUFFER, fbs.framebuffer);
    } else {
        glDeleteTextures(1, &fbs.render_texture);
        glDeleteFramebuffers(1, &fbs.framebuffer);
    }
}

pub fn preDraw(fbs: *FramebufferState) void {
    glBindFramebuffer(GL_FRAMEBUFFER, fbs.framebuffer);
}

pub fn postDraw(fbs: *FramebufferState, ds: *pdraw.DrawState, blit_rect: BlitRect, blit_alpha: f32) void {
    // blit renderbuffer to screen
    ds.projection = pdraw.ortho(0, 1, 1, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(blit_rect.x, blit_rect.y, blit_rect.w, blit_rect.h);
    pdraw.begin(ds, fbs.render_texture, draw.white, blit_alpha, false);
    pdraw.tile(ds, ds.blank_tileset, draw.Tile { .tx = 0, .ty = 0 }, 0, 0, 1, 1, .FlipVertical);
    pdraw.end(ds);
}
