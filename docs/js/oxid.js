(() => {
    const canvas_element = document.getElementById('canvasgl');
    const loading_text_element = document.getElementById('loading-text');

    const diagnostics = getDiagnostics(document.getElementById('diagnostics-table'));
    const diagnostics_webgl = diagnostics.addFeature('WebGL', 'canvas.getContext(\'webgl\', {antialias: false, preserveDrawingBuffer: true})');
    const diagnostics_fullscreen = diagnostics.addFeature('Fullscreen', 'canvas.requestFullscreen');
    const diagnostics_storage = diagnostics.addFeature('Persistent storage', 'window.localStorage');
    const diagnostics_audio = diagnostics.addFeature('Audio', 'window.AudioContext || window.webkitAudioContext');

    const storage = getStorage(diagnostics_storage);

    diagnostics_fullscreen.setAvailability(!!canvas_element.requestFullscreen);

    const assets = [
        'player_death.wav',
        'sfx_exp_short_soft10.wav',
        'sfx_sounds_impact1.wav',
        'sfx_sounds_interaction5.wav',
        'sfx_sounds_powerup4.wav',
    ];

    // these match same values in main_web.zig
    const NOP               = 1;
    const TOGGLE_SOUND      = 2;
    const TOGGLE_FULLSCREEN = 3;
    const SET_CANVAS_SCALE  = 100;

    // this will be filled out when assets are loaded
    const assets_dict = {};

    let audio_state = null;
    let audio_waiting = false;

    let is_fullscreen = false;
    let fullscreen_waiting = false;

    // this will be set to a `WebAssembly.Memory` object (it comes from
    // `instance.exports.memory`). when zig code calls an extern function
    // passing it a pointer, that value on the js side is an index into
    // `memory`.
    let memory;

    const readByteArray = (ptr, len) =>
        new Uint8Array(memory.buffer, ptr, len);
    const readString = (ptr, len) =>
        new TextDecoder().decode(readByteArray(ptr, len));

    const gl = canvas_element.getContext('webgl', {
        antialias: false,
        preserveDrawingBuffer: true,
    });
    diagnostics_webgl.setAvailability(!!gl);
    if (!gl) {
        loading_text_element.textContent = 'This browser does not support WebGL.';
        return;
    }

    // these are implementations of extern functions called from the zig side
    const env = {
        // WebGL functions
        // `memory` isn't initialized yet so we wrap in a getter function
        ...getWebGLEnv(gl, () => memory),
        // additional functions
        getRandomSeed() {
            return Math.floor(Math.random() * 2147483647);
        },
        consoleLog(ptr, len) {
            console.log(readString(ptr, len));
        },
        setLocalStorage(name_ptr, name_len, value_ptr, value_len) {
            const name = readString(name_ptr, name_len);
            const value = readByteArray(value_ptr, value_len);
            storage.setItem(name, value);
        },
        getLocalStorage(name_ptr, name_len, value_ptr, value_maxlen) {
            const name = readString(name_ptr, name_len);
            const value = storage.getItem(name);
            if (value === null) {
                return 0;
            }
            try {
                new Uint8Array(memory.buffer, value_ptr, value_maxlen).set(value);
            } catch (err) {
                console.warn('getLocalStorage failed to write into program memory:', err);
                return -1;
            }
            return value.length;
        },
        getAsset(name_ptr, name_len, result_addr_ptr, result_addr_len_ptr) {
            const name = readString(name_ptr, name_len);
            if (!(name in assets_dict)) {
                return false;
            }
            const ptr_view = new DataView(memory.buffer, result_addr_ptr, 4);
            const len_view = new DataView(memory.buffer, result_addr_len_ptr, 4);
            ptr_view.setUint32(0, assets_dict[name].ptr, true);
            len_view.setUint32(0, assets_dict[name].len, true);
            return true;
        },
    }

    const fetchBytes = (name) => {
        return fetch(name).then((response) => {
            if (!response.ok) {
                throw new Error('Failed to fetch ' + name);
            }
            return response.arrayBuffer();
        });
    };

    const writeAssetsIntoMemory = (assets) => {
        // allocate more memory to store the assets so they can be read by the zig side
        const total_assets_size = assets.reduce((pv, asset) => pv + asset.bytes.byteLength, 0);
        const wasm_page_size = 65536;
        const num_pages_to_add = Math.floor((total_assets_size + wasm_page_size - 1) / wasm_page_size);

        let memory_index = memory.buffer.byteLength;

        memory.grow(num_pages_to_add);

        // write contents into memory
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
    };

    // fetch wasm file in parallel with all the assets
    Promise.all([
        fetchBytes('oxid.wasm').then((bytes) => WebAssembly.instantiate(bytes, {env})),
        ...assets.map(name => fetchBytes('assets/' + name).then((bytes) => ({name, bytes}))),
    ]).then(([{instance}, ...assets]) => {
        memory = instance.exports.memory;

        writeAssetsIntoMemory(assets);

        // initialize game
        if (!instance.exports.onInit()) {
            loading_text_element.textContent = 'Failed to initialize game.';
            return;
        }

        loading_text_element.remove();

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
                // anything that isn't a known result code will not trigger
                // preventDefault
                return;
            }

            e.preventDefault();
        });
        document.addEventListener('keyup', (e) => {
            instance.exports.onKeyEvent(e.keyCode, 0);
        });

        canvas_element.addEventListener('fullscreenchange', (e) => {
            is_fullscreen = document.fullscreenElement === canvas_element;
            instance.exports.onFullscreenChange(is_fullscreen);
        });

        const step = (timestamp) => {
            instance.exports.onAnimationFrame(timestamp);
            window.requestAnimationFrame(step);
        };
        window.requestAnimationFrame(step);
    }).catch(err => {
        console.error(err);
        alert(err); // TODO don't do this...
    });

    function toggleSound(instance) {
        if (audio_waiting) {
            return;
        }
        if (audio_state === null) {
            // enable sound
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            diagnostics_audio.setAvailability(!!AudioContext);
            if (!AudioContext) {
                return;
            }

            const audio_buffer_size = instance.exports.getAudioBufferSize();
            const audio_context = new AudioContext();
            const script_processor_node = audio_context.createScriptProcessor(audio_buffer_size, 0, 1); // mono output
            script_processor_node.onaudioprocess = (event) => {
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
        const w = canvas_element.getAttribute('width');
        const h = canvas_element.getAttribute('height');
        canvas_element.style.width = (w * scale) + 'px';
        canvas_element.style.height = (h * scale) + 'px';
        instance.exports.onCanvasScaleChange(scale);
    }

    function toggleFullscreen() {
        if (fullscreen_waiting) {
            return;
        }
        if (!is_fullscreen) {
            if (canvas_element.requestFullscreen) {
                fullscreen_waiting = true;
                canvas_element.requestFullscreen().catch((err) => {
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
})();
