usingnamespace @cImport({
    @cInclude("epoxy/gl.h");
});

const pcx_helper = @import("../../common/pcx_helper.zig"); // FIXME - remove this dependency

pub const Texture = struct {
    handle: GLuint,
};

pub fn uploadTexture(img: pcx_helper.PcxImage) Texture {
    var texid: GLuint = undefined;
    glGenTextures(1, &texid);
    glBindTexture(GL_TEXTURE_2D, texid);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glTexImage2D(
        GL_TEXTURE_2D, // target
        0, // level
        GL_RGBA, // internalFormat
        @intCast(GLsizei, img.width), // width
        @intCast(GLsizei, img.height), // height
        0, // border
        GL_RGBA, // format
        GL_UNSIGNED_BYTE, // type
        &img.pixels[0], // data
    );
    return Texture {
        .handle = texid,
    };
}
