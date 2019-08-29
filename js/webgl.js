let webgl2Supported = (typeof WebGL2RenderingContext !== 'undefined');
let webgl_fallback = false;
let gl;

let webglOptions = {
  alpha: true, //Boolean that indicates if the canvas contains an alpha buffer.
  antialias: true,  //Boolean that indicates whether or not to perform anti-aliasing.
  depth: 32,  //Boolean that indicates that the drawing buffer has a depth buffer of at least 16 bits.
  failIfMajorPerformanceCaveat: false,  //Boolean that indicates if a context will be created if the system performance is low.
  powerPreference: "default", //A hint to the user agent indicating what configuration of GPU is suitable for the WebGL context. Possible values are:
  premultipliedAlpha: true,  //Boolean that indicates that the page compositor will assume the drawing buffer contains colors with pre-multiplied alpha.
  preserveDrawingBuffer: true,  //If the value is true the buffers will not be cleared and will preserve their values until cleared or overwritten by the author.
  stencil: true, //Boolean that indicates that the drawing buffer has a stencil buffer of at least 8 bits.
}

if (webgl2Supported) {
  gl = $webgl.getContext('webgl2', webglOptions);
  if (!gl) {
    throw new Error('The browser supports WebGL2, but initialization failed.');
  }
}
if (!gl) {
  webgl_fallback = true;
  gl = $webgl.getContext('webgl', webglOptions);

  if (!gl) {
    throw new Error('The browser does not support WebGL');
  }

  let vaoExt = gl.getExtension("OES_vertex_array_object");
  if (!ext) {
    throw new Error('The browser supports WebGL, but not the OES_vertex_array_object extension');
  }
  gl.createVertexArray = vaoExt.createVertexArrayOES,
  gl.deleteVertexArray = vaoExt.deleteVertexArrayOES,
  gl.isVertexArray = vaoExt.isVertexArrayOES,
  gl.bindVertexArray = vaoExt.bindVertexArrayOES,
  gl.createVertexArray = vaoExt.createVertexArrayOES;
}
if (!gl) {
  throw new Error('The browser supports WebGL, but initialization failed.');
}

const glShaders = [];
const glPrograms = [];
const glVertexArrays = [];
const glBuffers = [];
const glTextures = [];
const glFramebuffers = [];
const glUniformLocations = [];

const glInitShader = (sourcePtr, sourceLen, type) => {
  const source = readCharStr(sourcePtr, sourceLen);
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw "Error compiling shader:" + gl.getShaderInfoLog(shader);
  }
  glShaders.push(shader);
  return glShaders.length - 1;
}
const glLinkShaderProgram = (vertexShaderId, fragmentShaderId) => {
  const program = gl.createProgram();
  gl.attachShader(program, glShaders[vertexShaderId]);
  gl.attachShader(program, glShaders[fragmentShaderId]);
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw ("Error linking program:" + gl.getProgramInfoLog(program));
  }
  glPrograms.push(program);
  return glPrograms.length - 1;
}

function createGLTexture(ctx, image, texture) {
  ctx.enable(ctx.TEXTURE_2D);
  ctx.bindTexture(ctx.TEXTURE_2D, texture);
  ctx.texImage2D(ctx.TEXTURE_2D, 0, ctx.RGBA, ctx.RGBA, ctx.UNSIGNED_BYTE,
    image);
  ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_MAG_FILTER, ctx.LINEAR);
  ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_MIN_FILTER,
    ctx.LINEAR_MIPMAP_LINEAR);
  ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_WRAP_S, ctx.REPEAT);
  ctx.texParameteri(ctx.TEXTURE_2D, ctx.TEXTURE_WRAP_T, ctx.REPEAT);
  ctx.generateMipmap(ctx.TEXTURE_2D)
  ctx.bindTexture(ctx.TEXTURE_2D, null);
}

function loadImageTexture(gl, url) {
  var texture = gl.createTexture();
  texture.image = new Image();
  texture.image.crossOrigin = '';
  texture.image.onload = function () {
    createGLTexture(gl, texture.image, texture)
  }
  texture.image.src = url;
  return texture;
}

const glViewport = (x, y, width, height) => gl.viewport(x, y, width, height);
const glClearColor = (r, g, b, a) => gl.clearColor(r, g, b, a);
const glEnable = (x) => gl.enable(x);
const glDepthFunc = (x) => gl.depthFunc(x);
const glBlendFunc = (x, y) => gl.blendFunc(x, y);
const glClear = (x) => gl.clear(x);
const glGetAttribLocation = (programId, namePtr, nameLen) => gl.getAttribLocation(glPrograms[programId], readCharStr(namePtr, nameLen));
const glGetUniformLocation = (programId, namePtr, nameLen) => {
  glUniformLocations.push(gl.getUniformLocation(glPrograms[programId], readCharStr(namePtr, nameLen)));
  return glUniformLocations.length - 1;
};
const glUniform4fv = (locationId, x, y, z, w) => gl.uniform4fv(glUniformLocations[locationId], [x, y, z, w]);
const glUniformMatrix4fv = (locationId, dataLen, transpose, dataPtr) => {
  const floats = new Float32Array(memory.buffer, dataPtr, dataLen * 16);
  gl.uniformMatrix4fv(glUniformLocations[locationId], transpose, floats);
};
const glUniform1i = (locationId, x) => gl.uniform1i(glUniformLocations[locationId], x);
const glUniform1f = (locationId, x) => gl.uniform1f(glUniformLocations[locationId], x);
const glCreateBuffer = () => {
  glBuffers.push(gl.createBuffer());
  return glBuffers.length - 1;
}
const glGenBuffers = (num, dataPtr) => {
  const buffers = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    glBuffers.push(gl.createBuffer());
    console.log('created buffer', glBuffers.length - 1, glBuffers[glBuffers.length - 1]);
    buffers[n] = glBuffers.length - 1;
  }
}
const glDetachShader = (program, shader) => {
  gl.detachShader(glPrograms[program], glShaders[shader]);
};
const glDeleteProgram = (id) => {
  gl.deleteProgram(glPrograms[id]);
  glPrograms[id] = undefined;
};
const glDeleteBuffer = (id) => {
  gl.deleteBuffer(glBuffers[id]);
  glBuffers[id] = undefined;
};
const glDeleteBuffers = (num, dataPtr) => {
  const buffers = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    console.log('want to delete buffer', buffers[n], glBuffers[buffers[n]]);
    gl.deleteBuffer(glBuffers[buffers[n]]);
    glBuffers[buffers[n]] = undefined;
  }
};
const glDeleteShader = (id) => {
  gl.deleteShader(glShaders[id]);
  glShaders[id] = undefined;
};
const glBindBuffer = (type, bufferId) => gl.bindBuffer(type, glBuffers[bufferId]);
const glBufferData = (type, count, dataPtr, drawType) => {
  const floats = new Float32Array(memory.buffer, dataPtr, count);
  gl.bufferData(type, floats, drawType);
}
const glUseProgram = (programId) => {
    gl.useProgram(glPrograms[programId]);
};
const glEnableVertexAttribArray = (x) => gl.enableVertexAttribArray(x);
const glVertexAttribPointer = (attribLocation, size, type, normalize, stride, offset) => {
  gl.vertexAttribPointer(attribLocation, size, type, normalize, stride, offset);
}
const glDrawArrays = (type, offset, count) => gl.drawArrays(type, offset, count);
const glCreateTexture = () => {
  glTextures.push(gl.createTexture());
  return glTextures.length - 1;
};
const glGenTextures = (num, dataPtr) => {
  const textures = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateTexture();
    textures[n] = b;
  }
}
const glDeleteTextures = (num, dataPtr) => {
  const textures = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    gl.glCreateTexture(buffers[n]);
    glTextures[textures[n]] = undefined;
  }
};
const glDeleteTexture = (id) => {
  gl.deleteTexture(glShaders[id]);
  glTextures[id] = undefined;
};
const glBindTexture = (target, textureId) => gl.bindTexture(target, glTextures[textureId]);
const glTexImage2D = (target, level, internalFormat, width, height, border, format, type, dataPtr, dataLen) => {
  const data = dataLen > 0 ? new Uint8Array(memory.buffer, dataPtr, dataLen) : null;
  gl.texImage2D(target, level, internalFormat, width, height, border, format, type, data);
};
const glTexParameteri = (target, pname, param) => gl.texParameteri(target, pname, param);
const glTexParameterf = (target, pname, param) => gl.texParameterf(target, pname, param);
const glActiveTexture = (target) => gl.activeTexture(target);
const glCreateVertexArray = () => {
  glVertexArrays.push(gl.createVertexArray());
  return glVertexArrays.length - 1;
};
const glGenVertexArrays = (num, dataPtr) => {
  const vaos = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    const b = glCreateVertexArray();
    vaos[n] = b;
  }
}
const glDeleteVertexArrays = (num, dataPtr) => {
  const vaos = new Uint32Array(memory.buffer, dataPtr, num);
  for (let n = 0; n < num; n++) {
    gl.glCreateTexture(vaos[n]);
    glVertexArrays[vaos[n]] = undefined;
  }
};
const glBindVertexArray = (id) => gl.bindVertexArray(glVertexArrays[id]);
const glPixelStorei = (type, alignment) => gl.pixelStorei(type, alignment);
const glGetError = () => gl.getError();

const glCreateFramebuffer = () => {
    const framebuffer = gl.createFramebuffer();
    glFramebuffers.push(framebuffer);
    return glFramebuffers.length - 1;
};
const glBindFramebuffer = (target, framebuffer) => {
    gl.bindFramebuffer(target, glFramebuffers[framebuffer]);
};
//pub extern fn glFramebufferTexture2D(target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) void;
const glFramebufferTexture2D = (target, attachment, textarget, texture, level) => {
    gl.framebufferTexture2D(target, attachment, textarget, glTextures[texture], level);
};
//pub extern fn glDrawBuffers(n: GLsizei, bufs: [*c]const GLenum) void;
const glDrawBuffers = (num, bufs) => {
  const mem = new Uint32Array(memory.buffer, bufs, num);
  gl.drawBuffers(mem);
};
//pub extern fn glCheckFramebufferStatus(target: GLenum) GLenum;
const glCheckFramebufferStatus = (target) => {
    return gl.checkFramebufferStatus(target);
};
//pub const GL_COLOR_ATTACHMENT0: c_uint = 0x8CE0;
//pub const GL_FRAMEBUFFER_COMPLETE: c_uint = 0x8CD5;
//pub extern fn glDisable(cap: GLenum) void;
const glDisable = (cap) => {
    gl.disable(cap);
};
//pub const GL_CULL_FACE: c_uint = 0x0B44;
//pub extern fn glFrontFace(mode: GLenum) void;
const glFrontFace = (mode) => {
    gl.frontFace(mode);
};
//pub const GL_CCW: c_uint = 0x0901;
//pub const GL_STREAM_DRAW: c_uint = 0x88E0;
//pub extern fn glCreateProgram() GLuint;
const glCreateProgram = () => {
  const program = gl.createProgram();
  glPrograms.push(program);
  return glPrograms.length - 1;
};
//pub extern fn glCreateShader(shaderType: GLenum) GLuint;
const glCreateShader = (shaderType) => {
  const shader = gl.createShader(shaderType);
  glShaders.push(shader);
  return glShaders.length - 1;
};
//pub extern fn glLinkProgram(program: GLuint) void;
const glLinkProgram = (program) => {
  gl.linkProgram(glPrograms[program]);
  if (!gl.getProgramParameter(glPrograms[program], gl.LINK_STATUS)) {
    throw ("Error linking program:" + gl.getProgramInfoLog(glPrograms[program]));
  }
};
//pub extern fn glShaderSource(shader: GLuint, count: GLsizei, string: *const ?[*]const u8, length: *const GLint) void;
const glShaderSource = (shader, stringPtr, stringLen) => {
  const string = readCharStr(stringPtr, stringLen);
  gl.shaderSource(glShaders[shader], string);
};
//pub extern fn glCompileShader(shader: GLuint) void;
const glCompileShader = (shader) => {
  gl.compileShader(glShaders[shader]);
  if (!gl.getShaderParameter(glShaders[shader], gl.COMPILE_STATUS)) {
    throw "Error compiling shader:" + gl.getShaderInfoLog(glShaders[shader]);
  }
};

const glAttachShader = (program, shader) => {
    gl.attachShader(glPrograms[program], glShaders[shader]);
};
const glUniform4f = (locationId, x, y, w, z) => {
    gl.uniform4f(glUniformLocations[locationId], x, y, w, z);
};
const glPolygonMode = (mode) => {
    // not supported
};

var webgl = {
  glInitShader,
  glLinkShaderProgram,
  glDeleteProgram,
  glDetachShader,
  glDeleteShader,
  glViewport,
  glClearColor,
  glEnable,
  glDepthFunc,
  glBlendFunc,
  glClear,
  glGetAttribLocation,
  glGetUniformLocation,
  glUniform4fv,
  glUniformMatrix4fv,
  glUniform1i,
  glUniform1f,
  glCreateBuffer,
  glGenBuffers,
  glDeleteBuffer,
  glDeleteBuffers,
  glBindBuffer,
  glBufferData,
  glUseProgram,
  glEnableVertexAttribArray,
  glVertexAttribPointer,
  glDrawArrays,
  glCreateTexture,
  glGenTextures,
  glDeleteTextures,
  glDeleteTexture,
  glBindTexture,
  glTexImage2D,
  glTexParameteri,
  glTexParameterf,
  glActiveTexture,
  glCreateVertexArray,
  glGenVertexArrays,
  glDeleteVertexArrays,
  glBindVertexArray,
  glPixelStorei,
  glGetError,
  glCreateFramebuffer,
  glBindFramebuffer,
  glFramebufferTexture2D,
  glDrawBuffers,
  glCheckFramebufferStatus,
  glDisable,
  glFrontFace,
  glCreateProgram,
  glAttachShader,
  glLinkProgram,
  glCreateShader,
  glShaderSource,
  glCompileShader,
  glUniform4f,
  glPolygonMode,
};
