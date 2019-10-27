/* global $webgl */

// this is a `WebAssembly.Memory` object (it comes from
// `instance.exports.memory`). when zig code calls an extern function passing
// it a pointer, that value on the js side is an index into `memory`.
let memory;

// these match same values in main_web.zig
const NOP               = 1;
const TOGGLE_SOUND      = 2;
const TOGGLE_FULLSCREEN = 3;
const SET_CANVAS_SCALE  = 100;

// these are implementations of extern functions called from the zig side
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
    getAssetPtr_(name_ptr, name_len) {
        const name = new TextDecoder().decode(new Uint8Array(memory.buffer, name_ptr, name_len));
        if (name in assets_dict) {
            return assets_dict[name].ptr;
        } else {
            throw new Error('getAssetPtr: asset not found: ' + name); // FIXME?
        }
    },
    getAssetLen_(name_ptr, name_len) {
        const name = new TextDecoder().decode(new Uint8Array(memory.buffer, name_ptr, name_len));
        if (name in assets_dict) {
            return assets_dict[name].len;
        } else {
            throw new Error('getAssetLen: asset not found: ' + name); // FIXME?
        }
    },
}

let is_fullscreen = false;
let fullscreen_waiting = false;

const assets = [
    'assets/sfx_deathscream_human2.wav',
    'assets/sfx_exp_cluster7.wav',
    'assets/sfx_exp_short_soft10.wav',
    'assets/sfx_sounds_impact1.wav',
    'assets/sfx_sounds_interaction5.wav',
    'assets/sfx_sounds_powerup10.wav',
    'assets/sfx_sounds_powerup4.wav',
];

// this will be filled out when assets are loaded
const assets_dict = {};

// fetch wasm file in parallel with all the assets
Promise.all([
    fetch('oxid.wasm').then(response => {
        if (!response.ok) {
            throw new Error('Failed to fetch oxid.wasm');
        }
        return response.arrayBuffer();
    }).then(bytes => {
        return WebAssembly.instantiate(bytes, {env});
    }),
    ...assets.map(name => {
        // assume assets are served from the root path (/assets/...)
        return fetch('/' + name).then(response => {
            if (!response.ok) {
                throw new Error('Failed to fetch ' + name);
            }
            return response.arrayBuffer();
        }).then(bytes => {
            return {name, bytes};
        });
    }),
]).then(([{instance}, ...assets]) => {
    memory = instance.exports.memory;

    // allocate more memory to store the assets so they can be read by the zig side
    const total_assets_size = assets.reduce((pv, asset) => pv + asset.bytes.byteLength, 0);
    const wasm_page_size = 65536;
    const num_pages_to_add = Math.floor((total_assets_size + wasm_page_size - 1) / wasm_page_size);

    let memory_index = memory.buffer.byteLength;

    memory.grow(num_pages_to_add);

    // write assets into memory
    for (const asset of assets) {
        const dest = new Uint8Array(memory.buffer, memory_index, asset.bytes.byteLength);
        const src = new Uint8Array(asset.bytes);
        dest.set(src);

        assets_dict[asset.name] = {
            ptr: memory_index,
            len: asset.bytes.byteLength,
        };

        memory_index += asset.bytes.byteLength;
    }

    if (!instance.exports.onInit()) {
        document.getElementById('loading-text').textContent = 'Failed to initialize game.';
        return;
    }

    document.getElementById('loading-text').remove();

    // default to 3x scale
    setCanvasScale(instance, 3);

    document.addEventListener('keydown', (e) => {
        const result = instance.exports.onKeyEvent(e.keyCode, 1);

        switch (result) {
        case NOP:
            break;
        case TOGGLE_SOUND:
            toggleSound(instance);
            break;
        case TOGGLE_FULLSCREEN:
            toggleFullscreen();
            break;
        default:
            if (result >= SET_CANVAS_SCALE) {
                setCanvasScale(instance, result - SET_CANVAS_SCALE);
                break;
            }
            return;
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

function setCanvasScale(instance, scale) {
    $webgl.style.width = ($webgl.getAttribute('width') * scale) + 'px';
    $webgl.style.height = ($webgl.getAttribute('height') * scale) + 'px';
    instance.exports.onCanvasScaleChange(scale);
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
