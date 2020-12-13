// this file contains declarations for functions implemented on the javascript
// side.
//
// note: zig supports giving a namespace(?) to extern functions, like this:
//
//   extern "hello" funcName() void;
//
// if not specified, it seems to default to "env". this has to match with the
// JS side.

pub extern fn getRandomSeed() c_uint;
pub extern fn consoleLog(message_ptr: [*]const u8, message_len: c_uint) void;
pub extern fn getLocalStorage(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_maxlen: c_int) c_int;
pub extern fn setLocalStorage(name_ptr: [*]const u8, name_len: c_int, value_ptr: [*]const u8, value_len: c_int) void;
pub extern fn getAsset(name_ptr: [*]const u8, name_len: c_int, result_addr_ptr: *[*]const u8, result_addr_len_ptr: *c_int) bool;
