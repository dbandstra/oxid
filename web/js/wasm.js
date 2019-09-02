let memory;

const env = {
    ...webgl,
    getRandomSeed() {
        return Math.floor(Math.random() * 2147483647);
    },
    consoleLog_(ptr, len) {
        console.log(new TextDecoder().decode(new Uint8Array(memory.buffer, ptr, len)));
    },
    getLocalStorage_(name_ptr, name_len, value_ptr, value_maxlen) {
        const name = new TextDecoder().decode(new Uint8Array(memory.buffer, name_ptr, name_len));
        const value = base64js.toByteArray(window.localStorage.getItem(name) || '');
        try {
            new Uint8Array(memory.buffer, value_ptr, value_maxlen).set(value);
        } catch (err) {
            console.warn('getLocalStorage_:', err);
            return -1;
        }
        return value.length;
    },
    setLocalStorage_(name_ptr, name_len, value_ptr, value_len) {
        const name = new TextDecoder().decode(new Uint8Array(memory.buffer, name_ptr, name_len));
        const value = base64js.fromByteArray(new Uint8Array(memory.buffer, value_ptr, value_len));
        window.localStorage.setItem(name, value);
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
        document.getElementById('loading-text').textContent = 'Failed to initialize game.';
        return;
    }

    document.getElementById('loading-text').remove();

    document.addEventListener('keydown', (e) => {
        if (instance.exports.onKeyEvent(e.keyCode, 1)) {
            e.preventDefault();
        }
    });
    document.addEventListener('keyup', (e) => {
        instance.exports.onKeyEvent(e.keyCode, 0);
    });

    const step = (timestamp) => {
        instance.exports.onAnimationFrame(timestamp);
        window.requestAnimationFrame(step);
    };
    window.requestAnimationFrame(step);

    // some browsers block sound unless initialized in response to a user action
    document.getElementById('enable-sound-button').addEventListener('click', (event) => {
        // safari still calls it "webkitAudioContext"
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) {
            event.target.parentNode.replaceChild(document.createTextNode('AudioContext API not supported.'), event.target);
            return;
        }

        event.target.parentNode.replaceChild(document.createTextNode('Sound enabled.'), event.target);

        instance.exports.enableAudio();

        const audio_buffer_size = instance.exports.getAudioBufferSize();
        const ctx = new AudioContext();
        const scriptProcessorNode = ctx.createScriptProcessor(audio_buffer_size, 0, 1); // mono output
        scriptProcessorNode.onaudioprocess = function(event) {
            const samples = event.outputBuffer.getChannelData(0);
            const audio_buffer_ptr = instance.exports.audioCallback(ctx.sampleRate);
            // TODO - any way i can get rid of this `new`? is there a way to pass memory to the zig side?
            samples.set(new Float32Array(memory.buffer, audio_buffer_ptr, audio_buffer_size));
        };
        // Route it to the main output.
        scriptProcessorNode.connect(ctx.destination);
    });
}).catch(err => {
    alert(err);
});
