const gl = $webgl.getContext('webgl', {
    antialias: false,
    preserveDrawingBuffer: true,
});

if (!gl) {
    throw new Error('The browser does not support WebGL');
}
