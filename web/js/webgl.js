let webgl2Supported = (typeof WebGL2RenderingContext !== 'undefined');
let webgl_fallback = false;
let gl;

let webglOptions = {
    alpha: true, //Boolean that indicates if the canvas contains an alpha buffer.
    antialias: false,  //Boolean that indicates whether or not to perform anti-aliasing.
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
