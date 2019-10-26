/* global $webgl */

let memory;

// these match same values in main_web.zig
const NOP               = 1;
const TOGGLE_SOUND      = 2;
const TOGGLE_FULLSCREEN = 3;

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

let is_fullscreen = false;
let fullscreen_waiting = false;

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
        const result = instance.exports.onKeyEvent(e.keyCode, 1);

        switch (result) {
        default:
            return;
        case NOP:
            break;
        case TOGGLE_SOUND:
            toggleSound(instance);
            break;
        case TOGGLE_FULLSCREEN:
            toggleFullscreen();
            break;
        }

        e.preventDefault();
    });
    document.addEventListener('keyup', (e) => {
        instance.exports.onKeyEvent(e.keyCode, 0);
    });

    $webgl.addEventListener('fullscreenchange', (e) => {
        is_fullscreen = document.fullscreenElement === $webgl;
        instance.exports.onFullscreenChange(is_fullscreen);
    });

    const step = (timestamp) => {
        instance.exports.onAnimationFrame(timestamp);
        window.requestAnimationFrame(step);
    };
    window.requestAnimationFrame(step);
}).catch(err => {
    alert(err);
});

let audio_state = null;
let audio_waiting = false;

function toggleSound(instance) {
    if (audio_waiting) {
        return;
    }
    if (audio_state === null) {
        // enable sound
        const AudioContext = window.AudioContext || window.webkitAudioContext;
        if (!AudioContext) {
            alert('AudioContext API not supported.');
            return;
        }

        const audio_buffer_size = instance.exports.getAudioBufferSize();
        const audio_context = new AudioContext();
        const script_processor_node = audio_context.createScriptProcessor(audio_buffer_size, 0, 1); // mono output
        script_processor_node.onaudioprocess = function(event) {
            const samples = event.outputBuffer.getChannelData(0);
            const audio_buffer_ptr = instance.exports.audioCallback(audio_context.sampleRate);
            // TODO - any way i can get rid of this `new`? is there a way to pass memory to the zig side?
            samples.set(new Float32Array(memory.buffer, audio_buffer_ptr, audio_buffer_size));
        };
        // Route it to the main output.
        script_processor_node.connect(audio_context.destination);

        audio_state = {
            audio_context,
            script_processor_node,
        };
        instance.exports.onSoundEnabledChange(true);
    } else {
        // disable sound
        audio_waiting = true;
        audio_state.script_processor_node.disconnect();
        audio_state.audio_context.close().catch((err) => {
            console.error(err);
        }).then(() => {
            audio_waiting = false;
            audio_state = null;
            instance.exports.onSoundEnabledChange(false);
        });
        return;
    }
}

function toggleFullscreen() {
    if (fullscreen_waiting) {
        return;
    }
    if (!is_fullscreen) {
        if ($webgl.requestFullscreen) {
            fullscreen_waiting = true;
            $webgl.requestFullscreen().catch((err) => {
                console.error(err);
            }).then(() => {
                fullscreen_waiting = false;
            });
        }
    } else {
        fullscreen_waiting = true;
        document.exitFullscreen().catch((err) => {
            console.error(err);
        }).then(() => {
            fullscreen_waiting = false;
        });
    }
}
