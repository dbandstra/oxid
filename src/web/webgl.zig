// these aren't part of WebGL (since javascript has its own booleans) but i've been using them
pub const GL_FALSE = 0;
pub const GL_TRUE = 1;

// following are all standard WebGL 1 constants as per https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Constants#Standard_WebGL_1_constants

// clearing buffers
pub const GL_DEPTH_BUFFER_BIT = 0x00000100;
pub const GL_STENCIL_BUFFER_BIT = 0x00000400;
pub const GL_COLOR_BUFFER_BIT = 0x00004000;

// rendering primitives
pub const GL_POINTS = 0x0000;
pub const GL_LINES = 0x0001;
pub const GL_LINE_LOOP = 0x0002;
pub const GL_LINE_STRIP = 0x0003;
pub const GL_TRIANGLES = 0x0004;
pub const GL_TRIANGLE_STRIP = 0x0005;
pub const GL_TRIANGLE_FAN = 0x0006;

// blending modes
pub const GL_ZERO = 0;
pub const GL_ONE = 1;
pub const GL_SRC_COLOR = 0x0300;
pub const GL_ONE_MINUS_SRC_COLOR = 0x0301;
pub const GL_SRC_ALPHA = 0x0302;
pub const GL_ONE_MINUS_SRC_ALPHA = 0x0303;
pub const GL_DST_ALPHA = 0x0304;
pub const GL_ONE_MINUS_DST_ALPHA = 0x0305;
pub const GL_DST_COLOR = 0x0306;
pub const GL_ONE_MINUS_DST_COLOR = 0x0307;
pub const GL_SRC_ALPHA_SATURATE = 0x0308;
pub const GL_CONSTANT_COLOR = 0x8001;
pub const GL_ONE_MINUS_CONSTANT_COLOR = 0x8002;
pub const GL_CONSTANT_ALPHA = 0x8003;
pub const GL_ONE_MINUS_CONSTANT_ALPHA = 0x8004;

// blending equations
pub const GL_FUNC_ADD = 0x8006;
pub const GL_FUNC_SUBTRACT = 0x800A;
pub const GL_FUNC_REVERSE_SUBTRACT = 0x800B;

// getting GL parameter information
pub const GL_BLEND_EQUATION = 0x8009;
pub const GL_BLEND_EQUATION_RGB = 0x8009;
pub const GL_BLEND_EQUATION_ALPHA = 0x883D;
pub const GL_BLEND_DST_RGB = 0x80C8;
pub const GL_BLEND_SRC_RGB = 0x80C9;
pub const GL_BLEND_DST_ALPHA = 0x80CA;
pub const GL_BLEND_SRC_ALPHA = 0x80CB;
pub const GL_BLEND_COLOR = 0x8005;
pub const GL_ARRAY_BUFFER_BINDING = 0x8894;
pub const GL_ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
pub const GL_LINE_WIDTH = 0x0B21;
pub const GL_ALIASED_POINT_SIZE_RANGE = 0x846D;
pub const GL_ALIASED_LINE_WIDTH_RANGE = 0x846E;
pub const GL_CULL_FACE_MODE = 0x0B45;
pub const GL_FRONT_FACE = 0x0B46;
pub const GL_DEPTH_RANGE = 0x0B70;
pub const GL_DEPTH_WRITEMASK = 0x0B72;
pub const GL_DEPTH_CLEAR_VALUE = 0x0B73;
pub const GL_DEPTH_FUNC = 0x0B74;
pub const GL_STENCIL_CLEAR_VALUE = 0x0B91;
pub const GL_STENCIL_FUNC = 0x0B92;
pub const GL_STENCIL_FAIL = 0x0B94;
pub const GL_STENCIL_PASS_DEPTH_FAIL = 0x0B95;
pub const GL_STENCIL_PASS_DEPTH_PASS = 0x0B96;
pub const GL_STENCIL_REF = 0x0B97;
pub const GL_STENCIL_VALUE_MASK = 0x0B93;
pub const GL_STENCIL_WRITEMASK = 0x0B98;
pub const GL_STENCIL_BACK_FUNC = 0x8800;
pub const GL_STENCIL_BACK_FAIL = 0x8801;
pub const GL_STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
pub const GL_STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
pub const GL_STENCIL_BACK_REF = 0x8CA3;
pub const GL_STENCIL_BACK_VALUE_MASK = 0x8CA4;
pub const GL_STENCIL_BACK_WRITEMASK = 0x8CA5;
pub const GL_VIEWPORT = 0x0BA2;
pub const GL_SCISSOR_BOX = 0x0C10;
pub const GL_COLOR_CLEAR_VALUE = 0x0C22;
pub const GL_COLOR_WRITEMASK = 0x0C23;
pub const GL_UNPACK_ALIGNMENT = 0x0CF5;
pub const GL_PACK_ALIGNMENT = 0x0D05;
pub const GL_MAX_TEXTURE_SIZE = 0x0D33;
pub const GL_MAX_VIEWPORT_DIMS = 0x0D3A;
pub const GL_SUBPIXEL_BITS = 0x0D50;
pub const GL_RED_BITS = 0x0D52;
pub const GL_GREEN_BITS = 0x0D53;
pub const GL_BLUE_BITS = 0x0D54;
pub const GL_ALPHA_BITS = 0x0D55;
pub const GL_DEPTH_BITS = 0x0D56;
pub const GL_STENCIL_BITS = 0x0D57;
pub const GL_POLYGON_OFFSET_UNITS = 0x2A00;
pub const GL_POLYGON_OFFSET_FACTOR = 0x8038;
pub const GL_TEXTURE_BINDING_2D = 0x8069;
pub const GL_SAMPLE_BUFFERS = 0x80A8;
pub const GL_SAMPLES = 0x80A9;
pub const GL_SAMPLE_COVERAGE_VALUE = 0x80AA;
pub const GL_SAMPLE_COVERAGE_INVERT = 0x80AB;
pub const GL_COMPRESSED_TEXTURE_FORMATS = 0x86A3;
pub const GL_VENDOR = 0x1F00;
pub const GL_RENDERER = 0x1F01;
pub const GL_VERSION = 0x1F02;
pub const GL_IMPLEMENTATION_COLOR_READ_TYPE = 0x8B9A;
pub const GL_IMPLEMENTATION_COLOR_READ_FORMAT = 0x8B9B;
pub const GL_BROWSER_DEFAULT_WEBGL = 0x9244;

// buffers
pub const GL_STATIC_DRAW = 0x88E4;
pub const GL_STREAM_DRAW = 0x88E0;
pub const GL_DYNAMIC_DRAW = 0x88E8;
pub const GL_ARRAY_BUFFER = 0x8892;
pub const GL_ELEMENT_ARRAY_BUFFER = 0x8893;
pub const GL_BUFFER_SIZE = 0x8764;
pub const GL_BUFFER_USAGE = 0x8765;

// vertex attributes
pub const GL_CURRENT_VERTEX_ATTRIB = 0x8626;
pub const GL_VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
pub const GL_VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
pub const GL_VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
pub const GL_VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
pub const GL_VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
pub const GL_VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
pub const GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;

// culling
pub const GL_CULL_FACE = 0x0B44;
pub const GL_FRONT = 0x0404;
pub const GL_BACK = 0x0405;
pub const GL_FRONT_AND_BACK = 0x0408;

// enabling and disabling
pub const GL_BLEND = 0x0BE2;
pub const GL_DEPTH_TEST = 0x0B71;
pub const GL_DITHER = 0x0BD0;
pub const GL_POLYGON_OFFSET_FILL = 0x8037;
pub const GL_SAMPLE_ALPHA_TO_COVERAGE = 0x809E;
pub const GL_SAMPLE_COVERAGE = 0x80A0;
pub const GL_SCISSOR_TEST = 0x0C11;
pub const GL_STENCIL_TEST = 0x0B90;

// errors
pub const GL_NO_ERROR = 0;
pub const GL_INVALID_ENUM = 0x0500;
pub const GL_INVALID_VALUE = 0x0501;
pub const GL_INVALID_OPERATION = 0x0502;
pub const GL_OUT_OF_MEMORY = 0x0505;
pub const GL_CONTEXT_LOST_WEBGL = 0x9242;

// front face directions
pub const GL_CW = 0x0900;
pub const GL_CCW = 0x0901;

// hints
pub const GL_DONT_CARE = 0x1100;
pub const GL_FASTEST = 0x1101;
pub const GL_NICEST = 0x1102;
pub const GL_GENERATE_MIPMAP_HINT = 0x8192;

// data types
pub const GL_BYTE = 0x1400;
pub const GL_UNSIGNED_BYTE = 0x1401;
pub const GL_SHORT = 0x1402;
pub const GL_UNSIGNED_SHORT = 0x1403;
pub const GL_INT = 0x1404;
pub const GL_UNSIGNED_INT = 0x1405;
pub const GL_FLOAT = 0x1406;

// pixel formats
pub const GL_DEPTH_COMPONENT = 0x1902;
pub const GL_ALPHA = 0x1906;
pub const GL_RGB = 0x1907;
pub const GL_RGBA = 0x1908;
pub const GL_LUMINANCE = 0x1909;
pub const GL_LUMINANCE_ALPHA = 0x190A;

// pixel types
// pub const GL_UNSIGNED_BYTE = 0x1401; // defined above
pub const GL_UNSIGNED_SHORT_4_4_4_4 = 0x8033;
pub const GL_UNSIGNED_SHORT_5_5_5_1 = 0x8034;
pub const GL_UNSIGNED_SHORT_5_6_5 = 0x8363;

// shaders
pub const GL_FRAGMENT_SHADER = 0x8B30;
pub const GL_VERTEX_SHADER = 0x8B31;
pub const GL_COMPILE_STATUS = 0x8B81;
pub const GL_DELETE_STATUS = 0x8B80;
pub const GL_LINK_STATUS = 0x8B82;
pub const GL_VALIDATE_STATUS = 0x8B83;
pub const GL_ATTACHED_SHADERS = 0x8B85;
pub const GL_ACTIVE_ATTRIBUTES = 0x8B89;
pub const GL_ACTIVE_UNIFORMS = 0x8B86;
pub const GL_MAX_VERTEX_ATTRIBS = 0x8869;
pub const GL_MAX_VERTEX_UNIFORM_VECTORS = 0x8DFB;
pub const GL_MAX_VARYING_VECTORS = 0x8DFC;
pub const GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
pub const GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
pub const GL_MAX_TEXTURE_IMAGE_UNITS = 0x8872;
pub const GL_MAX_FRAGMENT_UNIFORM_VECTORS = 0x8DFD;
pub const GL_SHADER_TYPE = 0x8B4F;
pub const GL_SHADING_LANGUAGE_VERSION = 0x8B8C;
pub const GL_CURRENT_PROGRAM = 0x8B8D;

// depth or stencil tests
pub const GL_NEVER = 0x0200;
pub const GL_LESS = 0x0201;
pub const GL_EQUAL = 0x0202;
pub const GL_LEQUAL = 0x0203;
pub const GL_GREATER = 0x0204;
pub const GL_NOTEQUAL = 0x0205;
pub const GL_GEQUAL = 0x0206;
pub const GL_ALWAYS = 0x0207;

// stencil actions
pub const GL_KEEP = 0x1E00;
pub const GL_REPLACE = 0x1E01;
pub const GL_INCR = 0x1E02;
pub const GL_DECR = 0x1E03;
pub const GL_INVERT = 0x150A;
pub const GL_INCR_WRAP = 0x8507;
pub const GL_DECR_WRAP = 0x8508;

// textures
pub const GL_NEAREST = 0x2600;
pub const GL_LINEAR = 0x2601;
pub const GL_NEAREST_MIPMAP_NEAREST = 0x2700;
pub const GL_LINEAR_MIPMAP_NEAREST = 0x2701;
pub const GL_NEAREST_MIPMAP_LINEAR = 0x2702;
pub const GL_LINEAR_MIPMAP_LINEAR = 0x2703;
pub const GL_TEXTURE_MAG_FILTER = 0x2800;
pub const GL_TEXTURE_MIN_FILTER = 0x2801;
pub const GL_TEXTURE_WRAP_S = 0x2802;
pub const GL_TEXTURE_WRAP_T = 0x2803;
pub const GL_TEXTURE_2D = 0x0DE1;
pub const GL_TEXTURE = 0x1702;
pub const GL_TEXTURE_CUBE_MAP = 0x8513;
pub const GL_TEXTURE_BINDING_CUBE_MAP = 0x8514;
pub const GL_TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
pub const GL_TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
pub const GL_TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
pub const GL_MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C;
pub const GL_TEXTURE0 = 0x84C0;
pub const GL_TEXTURE1 = 0x84C1;
pub const GL_TEXTURE2 = 0x84C2;
pub const GL_TEXTURE3 = 0x84C3;
pub const GL_TEXTURE4 = 0x84C4;
pub const GL_TEXTURE5 = 0x84C5;
pub const GL_TEXTURE6 = 0x84C6;
pub const GL_TEXTURE7 = 0x84C7;
pub const GL_TEXTURE8 = 0x84C8;
pub const GL_TEXTURE9 = 0x84C9;
pub const GL_TEXTURE10 = 0x84CA;
pub const GL_TEXTURE11 = 0x84CB;
pub const GL_TEXTURE12 = 0x84CC;
pub const GL_TEXTURE13 = 0x84CD;
pub const GL_TEXTURE14 = 0x84CE;
pub const GL_TEXTURE15 = 0x84CF;
pub const GL_TEXTURE16 = 0x84D0;
pub const GL_TEXTURE17 = 0x84D1;
pub const GL_TEXTURE18 = 0x84D2;
pub const GL_TEXTURE19 = 0x84D3;
pub const GL_TEXTURE20 = 0x84D4;
pub const GL_TEXTURE21 = 0x84D5;
pub const GL_TEXTURE22 = 0x84D6;
pub const GL_TEXTURE23 = 0x84D7;
pub const GL_TEXTURE24 = 0x84D8;
pub const GL_TEXTURE25 = 0x84D9;
pub const GL_TEXTURE26 = 0x84DA;
pub const GL_TEXTURE27 = 0x84DB;
pub const GL_TEXTURE28 = 0x84DC;
pub const GL_TEXTURE29 = 0x84DD;
pub const GL_TEXTURE30 = 0x84DE;
pub const GL_TEXTURE31 = 0x84DF;
pub const GL_ACTIVE_TEXTURE = 0x84E0;
pub const GL_REPEAT = 0x2901;
pub const GL_CLAMP_TO_EDGE = 0x812F;
pub const GL_MIRRORED_REPEAT = 0x8370;

// uniform types
pub const GL_FLOAT_VEC2 = 0x8B50;
pub const GL_FLOAT_VEC3 = 0x8B51;
pub const GL_FLOAT_VEC4 = 0x8B52;
pub const GL_INT_VEC2 = 0x8B53;
pub const GL_INT_VEC3 = 0x8B54;
pub const GL_INT_VEC4 = 0x8B55;
pub const GL_BOOL = 0x8B56;
pub const GL_BOOL_VEC2 = 0x8B57;
pub const GL_BOOL_VEC3 = 0x8B58;
pub const GL_BOOL_VEC4 = 0x8B59;
pub const GL_FLOAT_MAT2 = 0x8B5A;
pub const GL_FLOAT_MAT3 = 0x8B5B;
pub const GL_FLOAT_MAT4 = 0x8B5C;
pub const GL_SAMPLER_2D = 0x8B5E;
pub const GL_SAMPLER_CUBE = 0x8B60;

// shader precision-specified types
pub const GL_LOW_FLOAT = 0x8DF0;
pub const GL_MEDIUM_FLOAT = 0x8DF1;
pub const GL_HIGH_FLOAT = 0x8DF2;
pub const GL_LOW_INT = 0x8DF3;
pub const GL_MEDIUM_INT = 0x8DF4;
pub const GL_HIGH_INT = 0x8DF5;

// framebuffers and renderbuffers
pub const GL_FRAMEBUFFER = 0x8D40;
pub const GL_RENDERBUFFER = 0x8D41;
pub const GL_RGBA4 = 0x8056;
pub const GL_RGB5_A1 = 0x8057;
pub const GL_RGB565 = 0x8D62;
pub const GL_DEPTH_COMPONENT16 = 0x81A5;
pub const GL_STENCIL_INDEX8 = 0x8D48;
pub const GL_DEPTH_STENCIL = 0x84F9;
pub const GL_RENDERBUFFER_WIDTH = 0x8D42;
pub const GL_RENDERBUFFER_HEIGHT = 0x8D43;
pub const GL_RENDERBUFFER_INTERNAL_FORMAT = 0x8D44;
pub const GL_RENDERBUFFER_RED_SIZE = 0x8D50;
pub const GL_RENDERBUFFER_GREEN_SIZE = 0x8D51;
pub const GL_RENDERBUFFER_BLUE_SIZE = 0x8D52;
pub const GL_RENDERBUFFER_ALPHA_SIZE = 0x8D53;
pub const GL_RENDERBUFFER_DEPTH_SIZE = 0x8D54;
pub const GL_RENDERBUFFER_STENCIL_SIZE = 0x8D55;
pub const GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0;
pub const GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1;
pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2;
pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3;
pub const GL_COLOR_ATTACHMENT0 = 0x8CE0;
pub const GL_DEPTH_ATTACHMENT = 0x8D00;
pub const GL_STENCIL_ATTACHMENT = 0x8D20;
pub const GL_DEPTH_STENCIL_ATTACHMENT = 0x821A;
pub const GL_NONE = 0;
pub const GL_FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6;
pub const GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7;
pub const GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS = 0x8CD9;
pub const GL_FRAMEBUFFER_UNSUPPORTED = 0x8CDD;
pub const GL_FRAMEBUFFER_BINDING = 0x8CA6;
pub const GL_RENDERBUFFER_BINDING = 0x8CA7;
pub const GL_MAX_RENDERBUFFER_SIZE = 0x84E8;
pub const GL_INVALID_FRAMEBUFFER_OPERATION = 0x0506;

// pixel storage modes
pub const GL_UNPACK_FLIP_Y_WEBGL = 0x9240;
pub const GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL = 0x9241;
pub const GL_UNPACK_COLORSPACE_CONVERSION_WEBGL = 0x9243;
