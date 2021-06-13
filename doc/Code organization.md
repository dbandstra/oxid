# Code organization

Table of contents:

* [Main files](#main-files)
* [src/oxid/](#srcoxid)
* [src/common/](#srccommon)
* [src/platform/](#srcplatform)
    * [pdate](#pdate)
    * [pdraw](#pdraw)
    * [passets](#passets)
    * [pstorage](#pstorage)
    * [Other files](#other-files)

## Main files

* `src/main_sdl_opengl.zig`
    * Main file for Oxid using SDL2 and the OpenGL implementation of `pdraw`
      (using OpenGL 2.1 + GL_ARB_framebuffer_object).
    * `zig build`
* `src/main_sdl_renderer.zig`
    * Main file for Oxid using SDL2 and the `SDL_render` implementation of
      `pdraw`.
    * Note: compared to the OpenGL build, this main file is missing some
      features such as framerate control, fast forwarding, and joystick
      support.
    * `zig build sdl_renderer`
* `src/main_web.zig`
    * Main file for Oxid WebAssembly build. Also uses the OpenGL
      implementation of `pdraw` (which supports WebGL 1).
    * `sh build_web.sh www` (which calls `zig build wasm` and copies
      artifacts to `www` folder where the game can be served).

## src/oxid/

Code specific to the Oxid game.

## src/common/

Game-agnostic code which could be reused in other projects.

* `drawing.zig`
    * Some code that is common to all implementations of the `pdraw`
      interface (see below).
    * Imports `@import("root").pdraw`.
* `fonts.zig`
    * Code for loading and drawing fixed-width fonts.
    * Imports `@import("root").pdraw`.
* `inputs.zig`
    * Canonical, platform-agnostic data models for input sources (keys,
      mouse/joystick buttons, etc).
* `math.zig`
    * Some basic types and functions for 2D games with `i32` coordinates.
* `pcx_helper.zig`
    * Function that loads a paletted PCX image at comptime (wrapper around
      low-level `zig-pcx` library).

## src/platform/

Platform-specific implementations of ad-hoc comptime interfaces.
Game-agnostic. For each interface there are multiple implementations (like
drivers that are chosen at build time). To use these, import them in your
main file, where they can be accessed from other files via `@import("root")`.

### pdate

Function for returning a formatted date in the current time zone. Zig doesn't
have support for this yet, so the native implementation uses libc.

The format used is hardcoded for now.

```zig
pub fn getDateTime(writer: anytype) !void
```

| Implementations |   |
|-----------------|---|
| `date_libc.zig` | Uses the `localtime` function from libc. |
| `date_web.zig`  | Uses an extern function which should be implemented on the JavaScript side. |

### pdraw

Very simple 2D graphics API. Imports `src/common/drawing.zig` (which provides
some implementation-independent types).

```zig
pub const Texture = // (opaque)
pub const State = // (opaque)

// init and deinit functions are not part of the common interface

// upload a texture. `pixels` can be freed after calling this
pub fn createTexture(ds: *State, w: u31, h: u31, pixels: []const u8) !Texture

// destroy an uploaded texture
pub fn destroyTexture(texture: Texture) void

// set a color which will tint all subsequent calls to `fill`, `rect`, or
// `tile`. to reset, set the color to `drawing.pure_white`.
pub fn setColor(ds: *State, color: drawing.Color) void

// draw a filled rectangle
pub fn fill(ds: *State, x: i32, y: i32, w: i32, h: i32) void

// draw a 1px-outlined rectangle
pub fn rect(ds: *State, x: i32, y: i32, w: i32, h: i32) void

// draw a tile from a tileset. it can be mirrored or rotated using the
// `transform` argument.
pub fn tile(
    ds: *State,
    tileset: drawing.Tileset,
    dtile: drawing.Tile,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    transform: drawing.Transform,
) void

// flush all queued draw calls. this should be called once per frame, at the
// end of rendering
pub fn flush(ds: *State) void
```

| Implementations   |   |
|-------------------|---|
| `draw_opengl.zig` | Supports OpenGL 2.1, OpenGL 3.0, and WebGL 1. |
| `draw_sdl.zig`    | Uses the SDL_render API (for which SDL provides many drivers, including software, OpenGL, Metal, etc). |

### passets

Load static assets at runtime.

```zig
// load an entire asset synchronously, and return its contents. `allocator` is
// used to allocate the returned slice. `hunk_side` is used for temporary
// allocations.
pub fn loadAsset(
    allocator: *std.mem.Allocator,
    hunk_side: *HunkSide,
    filename: []const u8,
) ![]const u8
```

|Implementations      |   |
|---------------------|---|
| `assets_web.zig`    | Uses an extern function which should be implemented on the JavaScript side. The idea is that JS code prefetches all assets before the wasm program is initialized, and then can provide them synchronously on demand here. |
| `assets_native.zig` | Loads asset from the filesystem. Uses `@import("build_options").assets_path`, which must be provided in `build.zig`. |

### pstorage

Read and write to persistent storage, useful for things like user config,
high scores, save files, etc.

```zig
// delete the storage object specified by `key`.
pub fn deleteObject(hunk_side: *HunkSide, key: []const u8) !void

pub const ReadableObject = struct {
    // the size in bytes of the opened object. do not write to this field.
    size: usize,

    // other struct fields are opaque

    pub const Reader = std.io.Reader(...); // some type of Reader

    // open the storage object specified by `key` for reading. if the object
    // does not yet exist, returns null. `hunk_side` is used for temporary
    // allocations.
    pub fn open(hunk_side: *HunkSide, key: []const u8) !?ReadableObject

    // close the storage object.
    pub fn close(self: ReadableObject) void

    // return a std.io.Reader object for reading from this object.
    pub fn reader(self: *ReadableObject) Reader
};

pub const WritableObject = struct {
    // struct fields are opaque

    pub const Writer = std.io.Writer(...); // some type of Writer
    pub const SeekableStream = std.io.SeekableStream(...);

    // open the storage object specified by `key` for writing. if the object
    // does not yet exist, it will be created. any subdirectories in the key
    // path will be created if they don't exist (in FS-backed
    // implementations). `hunk_side` is used for temporary allocations.
    pub fn open(hunk_side: *HunkSide, key: []const u8) !WritableObject

    // close the storage object.
    pub fn close(self: WritableObject) void

    // return a std.io.Writer for writing to this object.
    pub fn writer(self: *WritableObject) Writer

    // return a std.io.SeekableStream for seeking in the object.
    pub fn seekableStream(self: *WritableObject) SeekableStream
};
```

| Implementations      |   |
|----------------------|---|
| `storage_web.zig`    | Uses extern functions which should be implemented on the JavaScript side. In Oxid, this is backed by the browser's LocalStorage API. |
| `storage_native.zig` | Uses `@import("root").pstorage_dirname`. This is the name of the subdirectory to create within the user's app data folder, the path to which is retrieved using `std.fs.getAppDataDir`, which yields:<ul><li> Windows: `FOLDERID_LocalAppData` (e.g. `%USERPROFILE%/AppData/Local/`)<li>MacOS: `~/Library/Application Support/`<li>Linux, BSD: `~/.local/share/`</ul>`key` is used as the filename. |

### Other files

There are a few other files in `src/platform/` that are not part of interface
implementations.

* `sdl.zig`
    * Simply wraps an include of `SDL2/SDL.h`. This needs to be in its own
      Zig file because otherwise every import of the C header would create a
      new incompatible namespace.
* `sdl_key.zig`
    * Function to convert a `SDL_Keycode` to `inputs.Key` (from
      `src/common/inputs.zig`).
