let memory;

const env = {
    ...webgl,
    getRandomSeed() {
        return Math.floor(Math.random() * 2147483647);
    },
    consoleLog(ptr, len) {
        const bytes = new Uint8Array(memory.buffer, ptr, len);
        let s = "";
        for (let i = 0; i < len; ++i) {
            s += String.fromCharCode(bytes[i]);
        }
        console.log('consoleLog', s);
    },
}

fetch('oxid.wasm')
.then(response => response.arrayBuffer())
.then(bytes => WebAssembly.instantiate(bytes, {env}))
.then(({instance}) => {
    memory = instance.exports.memory;
    instance.exports.onInit();

    document.addEventListener('keydown', e => instance.exports.onKeyDown(e.keyCode));
    document.addEventListener('keyup', e => instance.exports.onKeyUp(e.keyCode));
    // document.addEventListener('mousedown', e => instance.exports.onMouseDown(e.button, e.x, e.y));
    // document.addEventListener('mouseup', e => instance.exports.onMouseUp(e.button, e.x, e.y));
    // document.addEventListener('mousemove', e => instance.exports.onMouseMove(e.x, e.y));
    // document.addEventListener('resize', e => instance.exports.onResize(e.width, e.height));

    const onAnimationFrame = instance.exports.onAnimationFrame;
    const step = (timestamp) => {
        onAnimationFrame(timestamp);
        window.requestAnimationFrame(step);
    };
    window.requestAnimationFrame(step);
});
