let memory;

const env = {
    ...webgl,
    getRandomSeed() {
        return Math.floor(Math.random() * 2147483647);
    },
    consoleLog_(ptr, len) {
        const bytes = new Uint8Array(memory.buffer, ptr, len);
        const str = new TextDecoder().decode(bytes);
        console.log('consoleLog', str);
    },
}

fetch('oxid.wasm').then(response => {
    if (!response.ok) {
        throw new Error('Failed to fetch oxid.wasm');
    }
    return response.arrayBuffer();
}).then(bytes => WebAssembly.instantiate(bytes, {env})).then(({instance}) => {
    memory = instance.exports.memory;

    if (!instance.exports.onInit()) {
        return;
    }

    document.addEventListener('keydown', (e) => {
        if (instance.exports.onKeyDown(e.keyCode)) {
            e.preventDefault();
        }
    });
    document.addEventListener('keyup', (e) => {
        if (instance.exports.onKeyUp(e.keyCode)) {
            e.preventDefault();
        }
    });

    const step = (timestamp) => {
        instance.exports.onAnimationFrame(timestamp);
        window.requestAnimationFrame(step);
    };
    window.requestAnimationFrame(step);
}).catch(err => {
    alert(err);
});
