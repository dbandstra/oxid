var memory;

const getRandomSeed = () => Math.floor(Math.random() * 2147483647);
const getRandomString = () => Math.random().toString(36).substring(5, 15) + Math.random().toString(36).substring(5, 15);
const consoleLog = (value) => console.log('consoleLog', value);
const readCharStr = (ptr, len) => {
    const bytes = new Uint8Array(memory.buffer, ptr, len);
    let s = "";
    for (let i = 0; i < len; ++i) {
        s += String.fromCharCode(bytes[i]);
    }
    return s;
}

var wasm = {
    consoleLog,
    getRandomSeed,
    getRandomString,
    consoleLogF: consoleLog,
    consoleLogS: (ptr, len) => {
        consoleLog(readCharStr(ptr, len));
    },
    readCharStr,
}
