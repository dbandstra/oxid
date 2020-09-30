pub const namespace = struct {
    pub const GLbitfield = u32;
    pub const GLboolean = u8;
    pub const GLbyte = i8;
    pub const GLchar = u8;
    pub const GLdouble = f64;
    pub const GLenum = u32;
    pub const GLfloat = f32;
    pub const GLint = i32;
    pub const GLintptr = isize;
    pub const GLshort = i16;
    pub const GLsizei = i32;
    pub const GLsizeiptr = isize;
    pub const GLubyte = u8;
    pub const GLuint = u32;
    pub const GLushort = u16;

    pub const GL_DEPTH_BUFFER_BIT = 0x00000100;
    pub const GL_STENCIL_BUFFER_BIT = 0x00000400;
    pub const GL_COLOR_BUFFER_BIT = 0x00004000;
    pub const GL_FALSE = 0;
    pub const GL_TRUE = 1;
    pub const GL_POINTS = 0x0000;
    pub const GL_LINES = 0x0001;
    pub const GL_LINE_LOOP = 0x0002;
    pub const GL_LINE_STRIP = 0x0003;
    pub const GL_TRIANGLES = 0x0004;
    pub const GL_TRIANGLE_STRIP = 0x0005;
    pub const GL_TRIANGLE_FAN = 0x0006;
    pub const GL_QUADS = 0x0007;
    pub const GL_NEVER = 0x0200;
    pub const GL_LESS = 0x0201;
    pub const GL_EQUAL = 0x0202;
    pub const GL_LEQUAL = 0x0203;
    pub const GL_GREATER = 0x0204;
    pub const GL_NOTEQUAL = 0x0205;
    pub const GL_GEQUAL = 0x0206;
    pub const GL_ALWAYS = 0x0207;
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
    pub const GL_NONE = 0;
    pub const GL_FRONT_LEFT = 0x0400;
    pub const GL_FRONT_RIGHT = 0x0401;
    pub const GL_BACK_LEFT = 0x0402;
    pub const GL_BACK_RIGHT = 0x0403;
    pub const GL_FRONT = 0x0404;
    pub const GL_BACK = 0x0405;
    pub const GL_LEFT = 0x0406;
    pub const GL_RIGHT = 0x0407;
    pub const GL_FRONT_AND_BACK = 0x0408;
    pub const GL_NO_ERROR = 0;
    pub const GL_INVALID_ENUM = 0x0500;
    pub const GL_INVALID_VALUE = 0x0501;
    pub const GL_INVALID_OPERATION = 0x0502;
    pub const GL_OUT_OF_MEMORY = 0x0505;
    pub const GL_CW = 0x0900;
    pub const GL_CCW = 0x0901;
    pub const GL_POINT_SIZE = 0x0B11;
    pub const GL_POINT_SIZE_RANGE = 0x0B12;
    pub const GL_POINT_SIZE_GRANULARITY = 0x0B13;
    pub const GL_LINE_SMOOTH = 0x0B20;
    pub const GL_LINE_WIDTH = 0x0B21;
    pub const GL_LINE_WIDTH_RANGE = 0x0B22;
    pub const GL_LINE_WIDTH_GRANULARITY = 0x0B23;
    pub const GL_POLYGON_MODE = 0x0B40;
    pub const GL_POLYGON_SMOOTH = 0x0B41;
    pub const GL_CULL_FACE = 0x0B44;
    pub const GL_CULL_FACE_MODE = 0x0B45;
    pub const GL_FRONT_FACE = 0x0B46;
    pub const GL_DEPTH_RANGE = 0x0B70;
    pub const GL_DEPTH_TEST = 0x0B71;
    pub const GL_DEPTH_WRITEMASK = 0x0B72;
    pub const GL_DEPTH_CLEAR_VALUE = 0x0B73;
    pub const GL_DEPTH_FUNC = 0x0B74;
    pub const GL_STENCIL_TEST = 0x0B90;
    pub const GL_STENCIL_CLEAR_VALUE = 0x0B91;
    pub const GL_STENCIL_FUNC = 0x0B92;
    pub const GL_STENCIL_VALUE_MASK = 0x0B93;
    pub const GL_STENCIL_FAIL = 0x0B94;
    pub const GL_STENCIL_PASS_DEPTH_FAIL = 0x0B95;
    pub const GL_STENCIL_PASS_DEPTH_PASS = 0x0B96;
    pub const GL_STENCIL_REF = 0x0B97;
    pub const GL_STENCIL_WRITEMASK = 0x0B98;
    pub const GL_VIEWPORT = 0x0BA2;
    pub const GL_DITHER = 0x0BD0;
    pub const GL_BLEND_DST = 0x0BE0;
    pub const GL_BLEND_SRC = 0x0BE1;
    pub const GL_BLEND = 0x0BE2;
    pub const GL_LOGIC_OP_MODE = 0x0BF0;
    pub const GL_DRAW_BUFFER = 0x0C01;
    pub const GL_READ_BUFFER = 0x0C02;
    pub const GL_SCISSOR_BOX = 0x0C10;
    pub const GL_SCISSOR_TEST = 0x0C11;
    pub const GL_COLOR_CLEAR_VALUE = 0x0C22;
    pub const GL_COLOR_WRITEMASK = 0x0C23;
    pub const GL_DOUBLEBUFFER = 0x0C32;
    pub const GL_STEREO = 0x0C33;
    pub const GL_LINE_SMOOTH_HINT = 0x0C52;
    pub const GL_POLYGON_SMOOTH_HINT = 0x0C53;
    pub const GL_UNPACK_SWAP_BYTES = 0x0CF0;
    pub const GL_UNPACK_LSB_FIRST = 0x0CF1;
    pub const GL_UNPACK_ROW_LENGTH = 0x0CF2;
    pub const GL_UNPACK_SKIP_ROWS = 0x0CF3;
    pub const GL_UNPACK_SKIP_PIXELS = 0x0CF4;
    pub const GL_UNPACK_ALIGNMENT = 0x0CF5;
    pub const GL_PACK_SWAP_BYTES = 0x0D00;
    pub const GL_PACK_LSB_FIRST = 0x0D01;
    pub const GL_PACK_ROW_LENGTH = 0x0D02;
    pub const GL_PACK_SKIP_ROWS = 0x0D03;
    pub const GL_PACK_SKIP_PIXELS = 0x0D04;
    pub const GL_PACK_ALIGNMENT = 0x0D05;
    pub const GL_MAX_TEXTURE_SIZE = 0x0D33;
    pub const GL_MAX_VIEWPORT_DIMS = 0x0D3A;
    pub const GL_SUBPIXEL_BITS = 0x0D50;
    pub const GL_TEXTURE_1D = 0x0DE0;
    pub const GL_TEXTURE_2D = 0x0DE1;
    pub const GL_TEXTURE_WIDTH = 0x1000;
    pub const GL_TEXTURE_HEIGHT = 0x1001;
    pub const GL_TEXTURE_BORDER_COLOR = 0x1004;
    pub const GL_DONT_CARE = 0x1100;
    pub const GL_FASTEST = 0x1101;
    pub const GL_NICEST = 0x1102;
    pub const GL_BYTE = 0x1400;
    pub const GL_UNSIGNED_BYTE = 0x1401;
    pub const GL_SHORT = 0x1402;
    pub const GL_UNSIGNED_SHORT = 0x1403;
    pub const GL_INT = 0x1404;
    pub const GL_UNSIGNED_INT = 0x1405;
    pub const GL_FLOAT = 0x1406;
    pub const GL_STACK_OVERFLOW = 0x0503;
    pub const GL_STACK_UNDERFLOW = 0x0504;
    pub const GL_CLEAR = 0x1500;
    pub const GL_AND = 0x1501;
    pub const GL_AND_REVERSE = 0x1502;
    pub const GL_COPY = 0x1503;
    pub const GL_AND_INVERTED = 0x1504;
    pub const GL_NOOP = 0x1505;
    pub const GL_XOR = 0x1506;
    pub const GL_OR = 0x1507;
    pub const GL_NOR = 0x1508;
    pub const GL_EQUIV = 0x1509;
    pub const GL_INVERT = 0x150A;
    pub const GL_OR_REVERSE = 0x150B;
    pub const GL_COPY_INVERTED = 0x150C;
    pub const GL_OR_INVERTED = 0x150D;
    pub const GL_NAND = 0x150E;
    pub const GL_SET = 0x150F;
    pub const GL_TEXTURE = 0x1702;
    pub const GL_COLOR = 0x1800;
    pub const GL_DEPTH = 0x1801;
    pub const GL_STENCIL = 0x1802;
    pub const GL_STENCIL_INDEX = 0x1901;
    pub const GL_DEPTH_COMPONENT = 0x1902;
    pub const GL_RED = 0x1903;
    pub const GL_GREEN = 0x1904;
    pub const GL_BLUE = 0x1905;
    pub const GL_ALPHA = 0x1906;
    pub const GL_RGB = 0x1907;
    pub const GL_RGBA = 0x1908;
    pub const GL_POINT = 0x1B00;
    pub const GL_LINE = 0x1B01;
    pub const GL_FILL = 0x1B02;
    pub const GL_KEEP = 0x1E00;
    pub const GL_REPLACE = 0x1E01;
    pub const GL_INCR = 0x1E02;
    pub const GL_DECR = 0x1E03;
    pub const GL_VENDOR = 0x1F00;
    pub const GL_RENDERER = 0x1F01;
    pub const GL_VERSION = 0x1F02;
    pub const GL_EXTENSIONS = 0x1F03;
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
    pub const GL_REPEAT = 0x2901;
    pub const GL_CURRENT_BIT = 0x00000001;
    pub const GL_POINT_BIT = 0x00000002;
    pub const GL_LINE_BIT = 0x00000004;
    pub const GL_POLYGON_BIT = 0x00000008;
    pub const GL_POLYGON_STIPPLE_BIT = 0x00000010;
    pub const GL_PIXEL_MODE_BIT = 0x00000020;
    pub const GL_LIGHTING_BIT = 0x00000040;
    pub const GL_FOG_BIT = 0x00000080;
    pub const GL_ACCUM_BUFFER_BIT = 0x00000200;
    pub const GL_VIEWPORT_BIT = 0x00000800;
    pub const GL_TRANSFORM_BIT = 0x00001000;
    pub const GL_ENABLE_BIT = 0x00002000;
    pub const GL_HINT_BIT = 0x00008000;
    pub const GL_EVAL_BIT = 0x00010000;
    pub const GL_LIST_BIT = 0x00020000;
    pub const GL_TEXTURE_BIT = 0x00040000;
    pub const GL_SCISSOR_BIT = 0x00080000;
    pub const GL_ALL_ATTRIB_BITS = 0xFFFFFFFF;
    pub const GL_QUAD_STRIP = 0x0008;
    pub const GL_POLYGON = 0x0009;
    pub const GL_ACCUM = 0x0100;
    pub const GL_LOAD = 0x0101;
    pub const GL_RETURN = 0x0102;
    pub const GL_MULT = 0x0103;
    pub const GL_ADD = 0x0104;
    pub const GL_AUX0 = 0x0409;
    pub const GL_AUX1 = 0x040A;
    pub const GL_AUX2 = 0x040B;
    pub const GL_AUX3 = 0x040C;
    pub const GL_2D = 0x0600;
    pub const GL_3D = 0x0601;
    pub const GL_3D_COLOR = 0x0602;
    pub const GL_3D_COLOR_TEXTURE = 0x0603;
    pub const GL_4D_COLOR_TEXTURE = 0x0604;
    pub const GL_PASS_THROUGH_TOKEN = 0x0700;
    pub const GL_POINT_TOKEN = 0x0701;
    pub const GL_LINE_TOKEN = 0x0702;
    pub const GL_POLYGON_TOKEN = 0x0703;
    pub const GL_BITMAP_TOKEN = 0x0704;
    pub const GL_DRAW_PIXEL_TOKEN = 0x0705;
    pub const GL_COPY_PIXEL_TOKEN = 0x0706;
    pub const GL_LINE_RESET_TOKEN = 0x0707;
    pub const GL_EXP = 0x0800;
    pub const GL_EXP2 = 0x0801;
    pub const GL_COEFF = 0x0A00;
    pub const GL_ORDER = 0x0A01;
    pub const GL_DOMAIN = 0x0A02;
    pub const GL_PIXEL_MAP_I_TO_I = 0x0C70;
    pub const GL_PIXEL_MAP_S_TO_S = 0x0C71;
    pub const GL_PIXEL_MAP_I_TO_R = 0x0C72;
    pub const GL_PIXEL_MAP_I_TO_G = 0x0C73;
    pub const GL_PIXEL_MAP_I_TO_B = 0x0C74;
    pub const GL_PIXEL_MAP_I_TO_A = 0x0C75;
    pub const GL_PIXEL_MAP_R_TO_R = 0x0C76;
    pub const GL_PIXEL_MAP_G_TO_G = 0x0C77;
    pub const GL_PIXEL_MAP_B_TO_B = 0x0C78;
    pub const GL_PIXEL_MAP_A_TO_A = 0x0C79;
    pub const GL_CURRENT_COLOR = 0x0B00;
    pub const GL_CURRENT_INDEX = 0x0B01;
    pub const GL_CURRENT_NORMAL = 0x0B02;
    pub const GL_CURRENT_TEXTURE_COORDS = 0x0B03;
    pub const GL_CURRENT_RASTER_COLOR = 0x0B04;
    pub const GL_CURRENT_RASTER_INDEX = 0x0B05;
    pub const GL_CURRENT_RASTER_TEXTURE_COORDS = 0x0B06;
    pub const GL_CURRENT_RASTER_POSITION = 0x0B07;
    pub const GL_CURRENT_RASTER_POSITION_VALID = 0x0B08;
    pub const GL_CURRENT_RASTER_DISTANCE = 0x0B09;
    pub const GL_POINT_SMOOTH = 0x0B10;
    pub const GL_LINE_STIPPLE = 0x0B24;
    pub const GL_LINE_STIPPLE_PATTERN = 0x0B25;
    pub const GL_LINE_STIPPLE_REPEAT = 0x0B26;
    pub const GL_LIST_MODE = 0x0B30;
    pub const GL_MAX_LIST_NESTING = 0x0B31;
    pub const GL_LIST_BASE = 0x0B32;
    pub const GL_LIST_INDEX = 0x0B33;
    pub const GL_POLYGON_STIPPLE = 0x0B42;
    pub const GL_EDGE_FLAG = 0x0B43;
    pub const GL_LIGHTING = 0x0B50;
    pub const GL_LIGHT_MODEL_LOCAL_VIEWER = 0x0B51;
    pub const GL_LIGHT_MODEL_TWO_SIDE = 0x0B52;
    pub const GL_LIGHT_MODEL_AMBIENT = 0x0B53;
    pub const GL_SHADE_MODEL = 0x0B54;
    pub const GL_COLOR_MATERIAL_FACE = 0x0B55;
    pub const GL_COLOR_MATERIAL_PARAMETER = 0x0B56;
    pub const GL_COLOR_MATERIAL = 0x0B57;
    pub const GL_FOG = 0x0B60;
    pub const GL_FOG_INDEX = 0x0B61;
    pub const GL_FOG_DENSITY = 0x0B62;
    pub const GL_FOG_START = 0x0B63;
    pub const GL_FOG_END = 0x0B64;
    pub const GL_FOG_MODE = 0x0B65;
    pub const GL_FOG_COLOR = 0x0B66;
    pub const GL_ACCUM_CLEAR_VALUE = 0x0B80;
    pub const GL_MATRIX_MODE = 0x0BA0;
    pub const GL_NORMALIZE = 0x0BA1;
    pub const GL_MODELVIEW_STACK_DEPTH = 0x0BA3;
    pub const GL_PROJECTION_STACK_DEPTH = 0x0BA4;
    pub const GL_TEXTURE_STACK_DEPTH = 0x0BA5;
    pub const GL_MODELVIEW_MATRIX = 0x0BA6;
    pub const GL_PROJECTION_MATRIX = 0x0BA7;
    pub const GL_TEXTURE_MATRIX = 0x0BA8;
    pub const GL_ATTRIB_STACK_DEPTH = 0x0BB0;
    pub const GL_ALPHA_TEST = 0x0BC0;
    pub const GL_ALPHA_TEST_FUNC = 0x0BC1;
    pub const GL_ALPHA_TEST_REF = 0x0BC2;
    pub const GL_LOGIC_OP = 0x0BF1;
    pub const GL_AUX_BUFFERS = 0x0C00;
    pub const GL_INDEX_CLEAR_VALUE = 0x0C20;
    pub const GL_INDEX_WRITEMASK = 0x0C21;
    pub const GL_INDEX_MODE = 0x0C30;
    pub const GL_RGBA_MODE = 0x0C31;
    pub const GL_RENDER_MODE = 0x0C40;
    pub const GL_PERSPECTIVE_CORRECTION_HINT = 0x0C50;
    pub const GL_POINT_SMOOTH_HINT = 0x0C51;
    pub const GL_FOG_HINT = 0x0C54;
    pub const GL_TEXTURE_GEN_S = 0x0C60;
    pub const GL_TEXTURE_GEN_T = 0x0C61;
    pub const GL_TEXTURE_GEN_R = 0x0C62;
    pub const GL_TEXTURE_GEN_Q = 0x0C63;
    pub const GL_PIXEL_MAP_I_TO_I_SIZE = 0x0CB0;
    pub const GL_PIXEL_MAP_S_TO_S_SIZE = 0x0CB1;
    pub const GL_PIXEL_MAP_I_TO_R_SIZE = 0x0CB2;
    pub const GL_PIXEL_MAP_I_TO_G_SIZE = 0x0CB3;
    pub const GL_PIXEL_MAP_I_TO_B_SIZE = 0x0CB4;
    pub const GL_PIXEL_MAP_I_TO_A_SIZE = 0x0CB5;
    pub const GL_PIXEL_MAP_R_TO_R_SIZE = 0x0CB6;
    pub const GL_PIXEL_MAP_G_TO_G_SIZE = 0x0CB7;
    pub const GL_PIXEL_MAP_B_TO_B_SIZE = 0x0CB8;
    pub const GL_PIXEL_MAP_A_TO_A_SIZE = 0x0CB9;
    pub const GL_MAP_COLOR = 0x0D10;
    pub const GL_MAP_STENCIL = 0x0D11;
    pub const GL_INDEX_SHIFT = 0x0D12;
    pub const GL_INDEX_OFFSET = 0x0D13;
    pub const GL_RED_SCALE = 0x0D14;
    pub const GL_RED_BIAS = 0x0D15;
    pub const GL_ZOOM_X = 0x0D16;
    pub const GL_ZOOM_Y = 0x0D17;
    pub const GL_GREEN_SCALE = 0x0D18;
    pub const GL_GREEN_BIAS = 0x0D19;
    pub const GL_BLUE_SCALE = 0x0D1A;
    pub const GL_BLUE_BIAS = 0x0D1B;
    pub const GL_ALPHA_SCALE = 0x0D1C;
    pub const GL_ALPHA_BIAS = 0x0D1D;
    pub const GL_DEPTH_SCALE = 0x0D1E;
    pub const GL_DEPTH_BIAS = 0x0D1F;
    pub const GL_MAX_EVAL_ORDER = 0x0D30;
    pub const GL_MAX_LIGHTS = 0x0D31;
    pub const GL_MAX_CLIP_PLANES = 0x0D32;
    pub const GL_MAX_PIXEL_MAP_TABLE = 0x0D34;
    pub const GL_MAX_ATTRIB_STACK_DEPTH = 0x0D35;
    pub const GL_MAX_MODELVIEW_STACK_DEPTH = 0x0D36;
    pub const GL_MAX_NAME_STACK_DEPTH = 0x0D37;
    pub const GL_MAX_PROJECTION_STACK_DEPTH = 0x0D38;
    pub const GL_MAX_TEXTURE_STACK_DEPTH = 0x0D39;
    pub const GL_INDEX_BITS = 0x0D51;
    pub const GL_RED_BITS = 0x0D52;
    pub const GL_GREEN_BITS = 0x0D53;
    pub const GL_BLUE_BITS = 0x0D54;
    pub const GL_ALPHA_BITS = 0x0D55;
    pub const GL_DEPTH_BITS = 0x0D56;
    pub const GL_STENCIL_BITS = 0x0D57;
    pub const GL_ACCUM_RED_BITS = 0x0D58;
    pub const GL_ACCUM_GREEN_BITS = 0x0D59;
    pub const GL_ACCUM_BLUE_BITS = 0x0D5A;
    pub const GL_ACCUM_ALPHA_BITS = 0x0D5B;
    pub const GL_NAME_STACK_DEPTH = 0x0D70;
    pub const GL_AUTO_NORMAL = 0x0D80;
    pub const GL_MAP1_COLOR_4 = 0x0D90;
    pub const GL_MAP1_INDEX = 0x0D91;
    pub const GL_MAP1_NORMAL = 0x0D92;
    pub const GL_MAP1_TEXTURE_COORD_1 = 0x0D93;
    pub const GL_MAP1_TEXTURE_COORD_2 = 0x0D94;
    pub const GL_MAP1_TEXTURE_COORD_3 = 0x0D95;
    pub const GL_MAP1_TEXTURE_COORD_4 = 0x0D96;
    pub const GL_MAP1_VERTEX_3 = 0x0D97;
    pub const GL_MAP1_VERTEX_4 = 0x0D98;
    pub const GL_MAP2_COLOR_4 = 0x0DB0;
    pub const GL_MAP2_INDEX = 0x0DB1;
    pub const GL_MAP2_NORMAL = 0x0DB2;
    pub const GL_MAP2_TEXTURE_COORD_1 = 0x0DB3;
    pub const GL_MAP2_TEXTURE_COORD_2 = 0x0DB4;
    pub const GL_MAP2_TEXTURE_COORD_3 = 0x0DB5;
    pub const GL_MAP2_TEXTURE_COORD_4 = 0x0DB6;
    pub const GL_MAP2_VERTEX_3 = 0x0DB7;
    pub const GL_MAP2_VERTEX_4 = 0x0DB8;
    pub const GL_MAP1_GRID_DOMAIN = 0x0DD0;
    pub const GL_MAP1_GRID_SEGMENTS = 0x0DD1;
    pub const GL_MAP2_GRID_DOMAIN = 0x0DD2;
    pub const GL_MAP2_GRID_SEGMENTS = 0x0DD3;
    pub const GL_TEXTURE_COMPONENTS = 0x1003;
    pub const GL_TEXTURE_BORDER = 0x1005;
    pub const GL_AMBIENT = 0x1200;
    pub const GL_DIFFUSE = 0x1201;
    pub const GL_SPECULAR = 0x1202;
    pub const GL_POSITION = 0x1203;
    pub const GL_SPOT_DIRECTION = 0x1204;
    pub const GL_SPOT_EXPONENT = 0x1205;
    pub const GL_SPOT_CUTOFF = 0x1206;
    pub const GL_CONSTANT_ATTENUATION = 0x1207;
    pub const GL_LINEAR_ATTENUATION = 0x1208;
    pub const GL_QUADRATIC_ATTENUATION = 0x1209;
    pub const GL_COMPILE = 0x1300;
    pub const GL_COMPILE_AND_EXECUTE = 0x1301;
    pub const GL_2_BYTES = 0x1407;
    pub const GL_3_BYTES = 0x1408;
    pub const GL_4_BYTES = 0x1409;
    pub const GL_EMISSION = 0x1600;
    pub const GL_SHININESS = 0x1601;
    pub const GL_AMBIENT_AND_DIFFUSE = 0x1602;
    pub const GL_COLOR_INDEXES = 0x1603;
    pub const GL_MODELVIEW = 0x1700;
    pub const GL_PROJECTION = 0x1701;
    pub const GL_COLOR_INDEX = 0x1900;
    pub const GL_LUMINANCE = 0x1909;
    pub const GL_LUMINANCE_ALPHA = 0x190A;
    pub const GL_BITMAP = 0x1A00;
    pub const GL_RENDER = 0x1C00;
    pub const GL_FEEDBACK = 0x1C01;
    pub const GL_SELECT = 0x1C02;
    pub const GL_FLAT = 0x1D00;
    pub const GL_SMOOTH = 0x1D01;
    pub const GL_S = 0x2000;
    pub const GL_T = 0x2001;
    pub const GL_R = 0x2002;
    pub const GL_Q = 0x2003;
    pub const GL_MODULATE = 0x2100;
    pub const GL_DECAL = 0x2101;
    pub const GL_TEXTURE_ENV_MODE = 0x2200;
    pub const GL_TEXTURE_ENV_COLOR = 0x2201;
    pub const GL_TEXTURE_ENV = 0x2300;
    pub const GL_EYE_LINEAR = 0x2400;
    pub const GL_OBJECT_LINEAR = 0x2401;
    pub const GL_SPHERE_MAP = 0x2402;
    pub const GL_TEXTURE_GEN_MODE = 0x2500;
    pub const GL_OBJECT_PLANE = 0x2501;
    pub const GL_EYE_PLANE = 0x2502;
    pub const GL_CLAMP = 0x2900;
    pub const GL_CLIP_PLANE0 = 0x3000;
    pub const GL_CLIP_PLANE1 = 0x3001;
    pub const GL_CLIP_PLANE2 = 0x3002;
    pub const GL_CLIP_PLANE3 = 0x3003;
    pub const GL_CLIP_PLANE4 = 0x3004;
    pub const GL_CLIP_PLANE5 = 0x3005;
    pub const GL_LIGHT0 = 0x4000;
    pub const GL_LIGHT1 = 0x4001;
    pub const GL_LIGHT2 = 0x4002;
    pub const GL_LIGHT3 = 0x4003;
    pub const GL_LIGHT4 = 0x4004;
    pub const GL_LIGHT5 = 0x4005;
    pub const GL_LIGHT6 = 0x4006;
    pub const GL_LIGHT7 = 0x4007;
    pub const GL_COLOR_LOGIC_OP = 0x0BF2;
    pub const GL_POLYGON_OFFSET_UNITS = 0x2A00;
    pub const GL_POLYGON_OFFSET_POINT = 0x2A01;
    pub const GL_POLYGON_OFFSET_LINE = 0x2A02;
    pub const GL_POLYGON_OFFSET_FILL = 0x8037;
    pub const GL_POLYGON_OFFSET_FACTOR = 0x8038;
    pub const GL_TEXTURE_BINDING_1D = 0x8068;
    pub const GL_TEXTURE_BINDING_2D = 0x8069;
    pub const GL_TEXTURE_INTERNAL_FORMAT = 0x1003;
    pub const GL_TEXTURE_RED_SIZE = 0x805C;
    pub const GL_TEXTURE_GREEN_SIZE = 0x805D;
    pub const GL_TEXTURE_BLUE_SIZE = 0x805E;
    pub const GL_TEXTURE_ALPHA_SIZE = 0x805F;
    pub const GL_DOUBLE = 0x140A;
    pub const GL_PROXY_TEXTURE_1D = 0x8063;
    pub const GL_PROXY_TEXTURE_2D = 0x8064;
    pub const GL_R3_G3_B2 = 0x2A10;
    pub const GL_RGB4 = 0x804F;
    pub const GL_RGB5 = 0x8050;
    pub const GL_RGB8 = 0x8051;
    pub const GL_RGB10 = 0x8052;
    pub const GL_RGB12 = 0x8053;
    pub const GL_RGB16 = 0x8054;
    pub const GL_RGBA2 = 0x8055;
    pub const GL_RGBA4 = 0x8056;
    pub const GL_RGB5_A1 = 0x8057;
    pub const GL_RGBA8 = 0x8058;
    pub const GL_RGB10_A2 = 0x8059;
    pub const GL_RGBA12 = 0x805A;
    pub const GL_RGBA16 = 0x805B;
    pub const GL_CLIENT_PIXEL_STORE_BIT = 0x00000001;
    pub const GL_CLIENT_VERTEX_ARRAY_BIT = 0x00000002;
    pub const GL_CLIENT_ALL_ATTRIB_BITS = 0xFFFFFFFF;
    pub const GL_VERTEX_ARRAY_POINTER = 0x808E;
    pub const GL_NORMAL_ARRAY_POINTER = 0x808F;
    pub const GL_COLOR_ARRAY_POINTER = 0x8090;
    pub const GL_INDEX_ARRAY_POINTER = 0x8091;
    pub const GL_TEXTURE_COORD_ARRAY_POINTER = 0x8092;
    pub const GL_EDGE_FLAG_ARRAY_POINTER = 0x8093;
    pub const GL_FEEDBACK_BUFFER_POINTER = 0x0DF0;
    pub const GL_SELECTION_BUFFER_POINTER = 0x0DF3;
    pub const GL_CLIENT_ATTRIB_STACK_DEPTH = 0x0BB1;
    pub const GL_INDEX_LOGIC_OP = 0x0BF1;
    pub const GL_MAX_CLIENT_ATTRIB_STACK_DEPTH = 0x0D3B;
    pub const GL_FEEDBACK_BUFFER_SIZE = 0x0DF1;
    pub const GL_FEEDBACK_BUFFER_TYPE = 0x0DF2;
    pub const GL_SELECTION_BUFFER_SIZE = 0x0DF4;
    pub const GL_VERTEX_ARRAY = 0x8074;
    pub const GL_NORMAL_ARRAY = 0x8075;
    pub const GL_COLOR_ARRAY = 0x8076;
    pub const GL_INDEX_ARRAY = 0x8077;
    pub const GL_TEXTURE_COORD_ARRAY = 0x8078;
    pub const GL_EDGE_FLAG_ARRAY = 0x8079;
    pub const GL_VERTEX_ARRAY_SIZE = 0x807A;
    pub const GL_VERTEX_ARRAY_TYPE = 0x807B;
    pub const GL_VERTEX_ARRAY_STRIDE = 0x807C;
    pub const GL_NORMAL_ARRAY_TYPE = 0x807E;
    pub const GL_NORMAL_ARRAY_STRIDE = 0x807F;
    pub const GL_COLOR_ARRAY_SIZE = 0x8081;
    pub const GL_COLOR_ARRAY_TYPE = 0x8082;
    pub const GL_COLOR_ARRAY_STRIDE = 0x8083;
    pub const GL_INDEX_ARRAY_TYPE = 0x8085;
    pub const GL_INDEX_ARRAY_STRIDE = 0x8086;
    pub const GL_TEXTURE_COORD_ARRAY_SIZE = 0x8088;
    pub const GL_TEXTURE_COORD_ARRAY_TYPE = 0x8089;
    pub const GL_TEXTURE_COORD_ARRAY_STRIDE = 0x808A;
    pub const GL_EDGE_FLAG_ARRAY_STRIDE = 0x808C;
    pub const GL_TEXTURE_LUMINANCE_SIZE = 0x8060;
    pub const GL_TEXTURE_INTENSITY_SIZE = 0x8061;
    pub const GL_TEXTURE_PRIORITY = 0x8066;
    pub const GL_TEXTURE_RESIDENT = 0x8067;
    pub const GL_ALPHA4 = 0x803B;
    pub const GL_ALPHA8 = 0x803C;
    pub const GL_ALPHA12 = 0x803D;
    pub const GL_ALPHA16 = 0x803E;
    pub const GL_LUMINANCE4 = 0x803F;
    pub const GL_LUMINANCE8 = 0x8040;
    pub const GL_LUMINANCE12 = 0x8041;
    pub const GL_LUMINANCE16 = 0x8042;
    pub const GL_LUMINANCE4_ALPHA4 = 0x8043;
    pub const GL_LUMINANCE6_ALPHA2 = 0x8044;
    pub const GL_LUMINANCE8_ALPHA8 = 0x8045;
    pub const GL_LUMINANCE12_ALPHA4 = 0x8046;
    pub const GL_LUMINANCE12_ALPHA12 = 0x8047;
    pub const GL_LUMINANCE16_ALPHA16 = 0x8048;
    pub const GL_INTENSITY = 0x8049;
    pub const GL_INTENSITY4 = 0x804A;
    pub const GL_INTENSITY8 = 0x804B;
    pub const GL_INTENSITY12 = 0x804C;
    pub const GL_INTENSITY16 = 0x804D;
    pub const GL_V2F = 0x2A20;
    pub const GL_V3F = 0x2A21;
    pub const GL_C4UB_V2F = 0x2A22;
    pub const GL_C4UB_V3F = 0x2A23;
    pub const GL_C3F_V3F = 0x2A24;
    pub const GL_N3F_V3F = 0x2A25;
    pub const GL_C4F_N3F_V3F = 0x2A26;
    pub const GL_T2F_V3F = 0x2A27;
    pub const GL_T4F_V4F = 0x2A28;
    pub const GL_T2F_C4UB_V3F = 0x2A29;
    pub const GL_T2F_C3F_V3F = 0x2A2A;
    pub const GL_T2F_N3F_V3F = 0x2A2B;
    pub const GL_T2F_C4F_N3F_V3F = 0x2A2C;
    pub const GL_T4F_C4F_N3F_V4F = 0x2A2D;
    pub const GL_UNSIGNED_BYTE_3_3_2 = 0x8032;
    pub const GL_UNSIGNED_SHORT_4_4_4_4 = 0x8033;
    pub const GL_UNSIGNED_SHORT_5_5_5_1 = 0x8034;
    pub const GL_UNSIGNED_INT_8_8_8_8 = 0x8035;
    pub const GL_UNSIGNED_INT_10_10_10_2 = 0x8036;
    pub const GL_TEXTURE_BINDING_3D = 0x806A;
    pub const GL_PACK_SKIP_IMAGES = 0x806B;
    pub const GL_PACK_IMAGE_HEIGHT = 0x806C;
    pub const GL_UNPACK_SKIP_IMAGES = 0x806D;
    pub const GL_UNPACK_IMAGE_HEIGHT = 0x806E;
    pub const GL_TEXTURE_3D = 0x806F;
    pub const GL_PROXY_TEXTURE_3D = 0x8070;
    pub const GL_TEXTURE_DEPTH = 0x8071;
    pub const GL_TEXTURE_WRAP_R = 0x8072;
    pub const GL_MAX_3D_TEXTURE_SIZE = 0x8073;
    pub const GL_UNSIGNED_BYTE_2_3_3_REV = 0x8362;
    pub const GL_UNSIGNED_SHORT_5_6_5 = 0x8363;
    pub const GL_UNSIGNED_SHORT_5_6_5_REV = 0x8364;
    pub const GL_UNSIGNED_SHORT_4_4_4_4_REV = 0x8365;
    pub const GL_UNSIGNED_SHORT_1_5_5_5_REV = 0x8366;
    pub const GL_UNSIGNED_INT_8_8_8_8_REV = 0x8367;
    pub const GL_UNSIGNED_INT_2_10_10_10_REV = 0x8368;
    pub const GL_BGR = 0x80E0;
    pub const GL_BGRA = 0x80E1;
    pub const GL_MAX_ELEMENTS_VERTICES = 0x80E8;
    pub const GL_MAX_ELEMENTS_INDICES = 0x80E9;
    pub const GL_CLAMP_TO_EDGE = 0x812F;
    pub const GL_TEXTURE_MIN_LOD = 0x813A;
    pub const GL_TEXTURE_MAX_LOD = 0x813B;
    pub const GL_TEXTURE_BASE_LEVEL = 0x813C;
    pub const GL_TEXTURE_MAX_LEVEL = 0x813D;
    pub const GL_SMOOTH_POINT_SIZE_RANGE = 0x0B12;
    pub const GL_SMOOTH_POINT_SIZE_GRANULARITY = 0x0B13;
    pub const GL_SMOOTH_LINE_WIDTH_RANGE = 0x0B22;
    pub const GL_SMOOTH_LINE_WIDTH_GRANULARITY = 0x0B23;
    pub const GL_ALIASED_LINE_WIDTH_RANGE = 0x846E;
    pub const GL_RESCALE_NORMAL = 0x803A;
    pub const GL_LIGHT_MODEL_COLOR_CONTROL = 0x81F8;
    pub const GL_SINGLE_COLOR = 0x81F9;
    pub const GL_SEPARATE_SPECULAR_COLOR = 0x81FA;
    pub const GL_ALIASED_POINT_SIZE_RANGE = 0x846D;
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
    pub const GL_MULTISAMPLE = 0x809D;
    pub const GL_SAMPLE_ALPHA_TO_COVERAGE = 0x809E;
    pub const GL_SAMPLE_ALPHA_TO_ONE = 0x809F;
    pub const GL_SAMPLE_COVERAGE = 0x80A0;
    pub const GL_SAMPLE_BUFFERS = 0x80A8;
    pub const GL_SAMPLES = 0x80A9;
    pub const GL_SAMPLE_COVERAGE_VALUE = 0x80AA;
    pub const GL_SAMPLE_COVERAGE_INVERT = 0x80AB;
    pub const GL_TEXTURE_CUBE_MAP = 0x8513;
    pub const GL_TEXTURE_BINDING_CUBE_MAP = 0x8514;
    pub const GL_TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
    pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
    pub const GL_TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
    pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
    pub const GL_TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
    pub const GL_TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
    pub const GL_PROXY_TEXTURE_CUBE_MAP = 0x851B;
    pub const GL_MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C;
    pub const GL_COMPRESSED_RGB = 0x84ED;
    pub const GL_COMPRESSED_RGBA = 0x84EE;
    pub const GL_TEXTURE_COMPRESSION_HINT = 0x84EF;
    pub const GL_TEXTURE_COMPRESSED_IMAGE_SIZE = 0x86A0;
    pub const GL_TEXTURE_COMPRESSED = 0x86A1;
    pub const GL_NUM_COMPRESSED_TEXTURE_FORMATS = 0x86A2;
    pub const GL_COMPRESSED_TEXTURE_FORMATS = 0x86A3;
    pub const GL_CLAMP_TO_BORDER = 0x812D;
    pub const GL_CLIENT_ACTIVE_TEXTURE = 0x84E1;
    pub const GL_MAX_TEXTURE_UNITS = 0x84E2;
    pub const GL_TRANSPOSE_MODELVIEW_MATRIX = 0x84E3;
    pub const GL_TRANSPOSE_PROJECTION_MATRIX = 0x84E4;
    pub const GL_TRANSPOSE_TEXTURE_MATRIX = 0x84E5;
    pub const GL_TRANSPOSE_COLOR_MATRIX = 0x84E6;
    pub const GL_MULTISAMPLE_BIT = 0x20000000;
    pub const GL_NORMAL_MAP = 0x8511;
    pub const GL_REFLECTION_MAP = 0x8512;
    pub const GL_COMPRESSED_ALPHA = 0x84E9;
    pub const GL_COMPRESSED_LUMINANCE = 0x84EA;
    pub const GL_COMPRESSED_LUMINANCE_ALPHA = 0x84EB;
    pub const GL_COMPRESSED_INTENSITY = 0x84EC;
    pub const GL_COMBINE = 0x8570;
    pub const GL_COMBINE_RGB = 0x8571;
    pub const GL_COMBINE_ALPHA = 0x8572;
    pub const GL_SOURCE0_RGB = 0x8580;
    pub const GL_SOURCE1_RGB = 0x8581;
    pub const GL_SOURCE2_RGB = 0x8582;
    pub const GL_SOURCE0_ALPHA = 0x8588;
    pub const GL_SOURCE1_ALPHA = 0x8589;
    pub const GL_SOURCE2_ALPHA = 0x858A;
    pub const GL_OPERAND0_RGB = 0x8590;
    pub const GL_OPERAND1_RGB = 0x8591;
    pub const GL_OPERAND2_RGB = 0x8592;
    pub const GL_OPERAND0_ALPHA = 0x8598;
    pub const GL_OPERAND1_ALPHA = 0x8599;
    pub const GL_OPERAND2_ALPHA = 0x859A;
    pub const GL_RGB_SCALE = 0x8573;
    pub const GL_ADD_SIGNED = 0x8574;
    pub const GL_INTERPOLATE = 0x8575;
    pub const GL_SUBTRACT = 0x84E7;
    pub const GL_CONSTANT = 0x8576;
    pub const GL_PRIMARY_COLOR = 0x8577;
    pub const GL_PREVIOUS = 0x8578;
    pub const GL_DOT3_RGB = 0x86AE;
    pub const GL_DOT3_RGBA = 0x86AF;
    pub const GL_BLEND_DST_RGB = 0x80C8;
    pub const GL_BLEND_SRC_RGB = 0x80C9;
    pub const GL_BLEND_DST_ALPHA = 0x80CA;
    pub const GL_BLEND_SRC_ALPHA = 0x80CB;
    pub const GL_POINT_FADE_THRESHOLD_SIZE = 0x8128;
    pub const GL_DEPTH_COMPONENT16 = 0x81A5;
    pub const GL_DEPTH_COMPONENT24 = 0x81A6;
    pub const GL_DEPTH_COMPONENT32 = 0x81A7;
    pub const GL_MIRRORED_REPEAT = 0x8370;
    pub const GL_MAX_TEXTURE_LOD_BIAS = 0x84FD;
    pub const GL_TEXTURE_LOD_BIAS = 0x8501;
    pub const GL_INCR_WRAP = 0x8507;
    pub const GL_DECR_WRAP = 0x8508;
    pub const GL_TEXTURE_DEPTH_SIZE = 0x884A;
    pub const GL_TEXTURE_COMPARE_MODE = 0x884C;
    pub const GL_TEXTURE_COMPARE_FUNC = 0x884D;
    pub const GL_POINT_SIZE_MIN = 0x8126;
    pub const GL_POINT_SIZE_MAX = 0x8127;
    pub const GL_POINT_DISTANCE_ATTENUATION = 0x8129;
    pub const GL_GENERATE_MIPMAP = 0x8191;
    pub const GL_GENERATE_MIPMAP_HINT = 0x8192;
    pub const GL_FOG_COORDINATE_SOURCE = 0x8450;
    pub const GL_FOG_COORDINATE = 0x8451;
    pub const GL_FRAGMENT_DEPTH = 0x8452;
    pub const GL_CURRENT_FOG_COORDINATE = 0x8453;
    pub const GL_FOG_COORDINATE_ARRAY_TYPE = 0x8454;
    pub const GL_FOG_COORDINATE_ARRAY_STRIDE = 0x8455;
    pub const GL_FOG_COORDINATE_ARRAY_POINTER = 0x8456;
    pub const GL_FOG_COORDINATE_ARRAY = 0x8457;
    pub const GL_COLOR_SUM = 0x8458;
    pub const GL_CURRENT_SECONDARY_COLOR = 0x8459;
    pub const GL_SECONDARY_COLOR_ARRAY_SIZE = 0x845A;
    pub const GL_SECONDARY_COLOR_ARRAY_TYPE = 0x845B;
    pub const GL_SECONDARY_COLOR_ARRAY_STRIDE = 0x845C;
    pub const GL_SECONDARY_COLOR_ARRAY_POINTER = 0x845D;
    pub const GL_SECONDARY_COLOR_ARRAY = 0x845E;
    pub const GL_TEXTURE_FILTER_CONTROL = 0x8500;
    pub const GL_DEPTH_TEXTURE_MODE = 0x884B;
    pub const GL_COMPARE_R_TO_TEXTURE = 0x884E;
    pub const GL_BLEND_COLOR = 0x8005;
    pub const GL_BLEND_EQUATION = 0x8009;
    pub const GL_CONSTANT_COLOR = 0x8001;
    pub const GL_ONE_MINUS_CONSTANT_COLOR = 0x8002;
    pub const GL_CONSTANT_ALPHA = 0x8003;
    pub const GL_ONE_MINUS_CONSTANT_ALPHA = 0x8004;
    pub const GL_FUNC_ADD = 0x8006;
    pub const GL_FUNC_REVERSE_SUBTRACT = 0x800B;
    pub const GL_FUNC_SUBTRACT = 0x800A;
    pub const GL_MIN = 0x8007;
    pub const GL_MAX = 0x8008;
    pub const GL_BUFFER_SIZE = 0x8764;
    pub const GL_BUFFER_USAGE = 0x8765;
    pub const GL_QUERY_COUNTER_BITS = 0x8864;
    pub const GL_CURRENT_QUERY = 0x8865;
    pub const GL_QUERY_RESULT = 0x8866;
    pub const GL_QUERY_RESULT_AVAILABLE = 0x8867;
    pub const GL_ARRAY_BUFFER = 0x8892;
    pub const GL_ELEMENT_ARRAY_BUFFER = 0x8893;
    pub const GL_ARRAY_BUFFER_BINDING = 0x8894;
    pub const GL_ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
    pub const GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
    pub const GL_READ_ONLY = 0x88B8;
    pub const GL_WRITE_ONLY = 0x88B9;
    pub const GL_READ_WRITE = 0x88BA;
    pub const GL_BUFFER_ACCESS = 0x88BB;
    pub const GL_BUFFER_MAPPED = 0x88BC;
    pub const GL_BUFFER_MAP_POINTER = 0x88BD;
    pub const GL_STREAM_DRAW = 0x88E0;
    pub const GL_STREAM_READ = 0x88E1;
    pub const GL_STREAM_COPY = 0x88E2;
    pub const GL_STATIC_DRAW = 0x88E4;
    pub const GL_STATIC_READ = 0x88E5;
    pub const GL_STATIC_COPY = 0x88E6;
    pub const GL_DYNAMIC_DRAW = 0x88E8;
    pub const GL_DYNAMIC_READ = 0x88E9;
    pub const GL_DYNAMIC_COPY = 0x88EA;
    pub const GL_SAMPLES_PASSED = 0x8914;
    pub const GL_SRC1_ALPHA = 0x8589;
    pub const GL_VERTEX_ARRAY_BUFFER_BINDING = 0x8896;
    pub const GL_NORMAL_ARRAY_BUFFER_BINDING = 0x8897;
    pub const GL_COLOR_ARRAY_BUFFER_BINDING = 0x8898;
    pub const GL_INDEX_ARRAY_BUFFER_BINDING = 0x8899;
    pub const GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING = 0x889A;
    pub const GL_EDGE_FLAG_ARRAY_BUFFER_BINDING = 0x889B;
    pub const GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING = 0x889C;
    pub const GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING = 0x889D;
    pub const GL_WEIGHT_ARRAY_BUFFER_BINDING = 0x889E;
    pub const GL_FOG_COORD_SRC = 0x8450;
    pub const GL_FOG_COORD = 0x8451;
    pub const GL_CURRENT_FOG_COORD = 0x8453;
    pub const GL_FOG_COORD_ARRAY_TYPE = 0x8454;
    pub const GL_FOG_COORD_ARRAY_STRIDE = 0x8455;
    pub const GL_FOG_COORD_ARRAY_POINTER = 0x8456;
    pub const GL_FOG_COORD_ARRAY = 0x8457;
    pub const GL_FOG_COORD_ARRAY_BUFFER_BINDING = 0x889D;
    pub const GL_SRC0_RGB = 0x8580;
    pub const GL_SRC1_RGB = 0x8581;
    pub const GL_SRC2_RGB = 0x8582;
    pub const GL_SRC0_ALPHA = 0x8588;
    pub const GL_SRC2_ALPHA = 0x858A;
    pub const GL_BLEND_EQUATION_RGB = 0x8009;
    pub const GL_VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
    pub const GL_VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
    pub const GL_VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
    pub const GL_VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
    pub const GL_CURRENT_VERTEX_ATTRIB = 0x8626;
    pub const GL_VERTEX_PROGRAM_POINT_SIZE = 0x8642;
    pub const GL_VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
    pub const GL_STENCIL_BACK_FUNC = 0x8800;
    pub const GL_STENCIL_BACK_FAIL = 0x8801;
    pub const GL_STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
    pub const GL_STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
    pub const GL_MAX_DRAW_BUFFERS = 0x8824;
    pub const GL_DRAW_BUFFER0 = 0x8825;
    pub const GL_DRAW_BUFFER1 = 0x8826;
    pub const GL_DRAW_BUFFER2 = 0x8827;
    pub const GL_DRAW_BUFFER3 = 0x8828;
    pub const GL_DRAW_BUFFER4 = 0x8829;
    pub const GL_DRAW_BUFFER5 = 0x882A;
    pub const GL_DRAW_BUFFER6 = 0x882B;
    pub const GL_DRAW_BUFFER7 = 0x882C;
    pub const GL_DRAW_BUFFER8 = 0x882D;
    pub const GL_DRAW_BUFFER9 = 0x882E;
    pub const GL_DRAW_BUFFER10 = 0x882F;
    pub const GL_DRAW_BUFFER11 = 0x8830;
    pub const GL_DRAW_BUFFER12 = 0x8831;
    pub const GL_DRAW_BUFFER13 = 0x8832;
    pub const GL_DRAW_BUFFER14 = 0x8833;
    pub const GL_DRAW_BUFFER15 = 0x8834;
    pub const GL_BLEND_EQUATION_ALPHA = 0x883D;
    pub const GL_MAX_VERTEX_ATTRIBS = 0x8869;
    pub const GL_VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
    pub const GL_MAX_TEXTURE_IMAGE_UNITS = 0x8872;
    pub const GL_FRAGMENT_SHADER = 0x8B30;
    pub const GL_VERTEX_SHADER = 0x8B31;
    pub const GL_MAX_FRAGMENT_UNIFORM_COMPONENTS = 0x8B49;
    pub const GL_MAX_VERTEX_UNIFORM_COMPONENTS = 0x8B4A;
    pub const GL_MAX_VARYING_FLOATS = 0x8B4B;
    pub const GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
    pub const GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
    pub const GL_SHADER_TYPE = 0x8B4F;
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
    pub const GL_SAMPLER_1D = 0x8B5D;
    pub const GL_SAMPLER_2D = 0x8B5E;
    pub const GL_SAMPLER_3D = 0x8B5F;
    pub const GL_SAMPLER_CUBE = 0x8B60;
    pub const GL_SAMPLER_1D_SHADOW = 0x8B61;
    pub const GL_SAMPLER_2D_SHADOW = 0x8B62;
    pub const GL_DELETE_STATUS = 0x8B80;
    pub const GL_COMPILE_STATUS = 0x8B81;
    pub const GL_LINK_STATUS = 0x8B82;
    pub const GL_VALIDATE_STATUS = 0x8B83;
    pub const GL_INFO_LOG_LENGTH = 0x8B84;
    pub const GL_ATTACHED_SHADERS = 0x8B85;
    pub const GL_ACTIVE_UNIFORMS = 0x8B86;
    pub const GL_ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87;
    pub const GL_SHADER_SOURCE_LENGTH = 0x8B88;
    pub const GL_ACTIVE_ATTRIBUTES = 0x8B89;
    pub const GL_ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A;
    pub const GL_FRAGMENT_SHADER_DERIVATIVE_HINT = 0x8B8B;
    pub const GL_SHADING_LANGUAGE_VERSION = 0x8B8C;
    pub const GL_CURRENT_PROGRAM = 0x8B8D;
    pub const GL_POINT_SPRITE_COORD_ORIGIN = 0x8CA0;
    pub const GL_LOWER_LEFT = 0x8CA1;
    pub const GL_UPPER_LEFT = 0x8CA2;
    pub const GL_STENCIL_BACK_REF = 0x8CA3;
    pub const GL_STENCIL_BACK_VALUE_MASK = 0x8CA4;
    pub const GL_STENCIL_BACK_WRITEMASK = 0x8CA5;
    pub const GL_VERTEX_PROGRAM_TWO_SIDE = 0x8643;
    pub const GL_POINT_SPRITE = 0x8861;
    pub const GL_COORD_REPLACE = 0x8862;
    pub const GL_MAX_TEXTURE_COORDS = 0x8871;
    pub const GL_PIXEL_PACK_BUFFER = 0x88EB;
    pub const GL_PIXEL_UNPACK_BUFFER = 0x88EC;
    pub const GL_PIXEL_PACK_BUFFER_BINDING = 0x88ED;
    pub const GL_PIXEL_UNPACK_BUFFER_BINDING = 0x88EF;
    pub const GL_FLOAT_MAT2x3 = 0x8B65;
    pub const GL_FLOAT_MAT2x4 = 0x8B66;
    pub const GL_FLOAT_MAT3x2 = 0x8B67;
    pub const GL_FLOAT_MAT3x4 = 0x8B68;
    pub const GL_FLOAT_MAT4x2 = 0x8B69;
    pub const GL_FLOAT_MAT4x3 = 0x8B6A;
    pub const GL_SRGB = 0x8C40;
    pub const GL_SRGB8 = 0x8C41;
    pub const GL_SRGB_ALPHA = 0x8C42;
    pub const GL_SRGB8_ALPHA8 = 0x8C43;
    pub const GL_COMPRESSED_SRGB = 0x8C48;
    pub const GL_COMPRESSED_SRGB_ALPHA = 0x8C49;
    pub const GL_CURRENT_RASTER_SECONDARY_COLOR = 0x845F;
    pub const GL_SLUMINANCE_ALPHA = 0x8C44;
    pub const GL_SLUMINANCE8_ALPHA8 = 0x8C45;
    pub const GL_SLUMINANCE = 0x8C46;
    pub const GL_SLUMINANCE8 = 0x8C47;
    pub const GL_COMPRESSED_SLUMINANCE = 0x8C4A;
    pub const GL_COMPRESSED_SLUMINANCE_ALPHA = 0x8C4B;
    pub const GL_INVALID_FRAMEBUFFER_OPERATION = 0x0506;
    pub const GL_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = 0x8210;
    pub const GL_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = 0x8211;
    pub const GL_FRAMEBUFFER_ATTACHMENT_RED_SIZE = 0x8212;
    pub const GL_FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = 0x8213;
    pub const GL_FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = 0x8214;
    pub const GL_FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = 0x8215;
    pub const GL_FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = 0x8216;
    pub const GL_FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = 0x8217;
    pub const GL_FRAMEBUFFER_DEFAULT = 0x8218;
    pub const GL_FRAMEBUFFER_UNDEFINED = 0x8219;
    pub const GL_DEPTH_STENCIL_ATTACHMENT = 0x821A;
    pub const GL_MAX_RENDERBUFFER_SIZE = 0x84E8;
    pub const GL_DEPTH_STENCIL = 0x84F9;
    pub const GL_UNSIGNED_INT_24_8 = 0x84FA;
    pub const GL_DEPTH24_STENCIL8 = 0x88F0;
    pub const GL_TEXTURE_STENCIL_SIZE = 0x88F1;
    pub const GL_UNSIGNED_NORMALIZED = 0x8C17;
    pub const GL_FRAMEBUFFER_BINDING = 0x8CA6;
    pub const GL_DRAW_FRAMEBUFFER_BINDING = 0x8CA6;
    pub const GL_RENDERBUFFER_BINDING = 0x8CA7;
    pub const GL_READ_FRAMEBUFFER = 0x8CA8;
    pub const GL_DRAW_FRAMEBUFFER = 0x8CA9;
    pub const GL_READ_FRAMEBUFFER_BINDING = 0x8CAA;
    pub const GL_RENDERBUFFER_SAMPLES = 0x8CAB;
    pub const GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0;
    pub const GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1;
    pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2;
    pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3;
    pub const GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = 0x8CD4;
    pub const GL_FRAMEBUFFER_COMPLETE = 0x8CD5;
    pub const GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6;
    pub const GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7;
    pub const GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER = 0x8CDB;
    pub const GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER = 0x8CDC;
    pub const GL_FRAMEBUFFER_UNSUPPORTED = 0x8CDD;
    pub const GL_MAX_COLOR_ATTACHMENTS = 0x8CDF;
    pub const GL_COLOR_ATTACHMENT0 = 0x8CE0;
    pub const GL_COLOR_ATTACHMENT1 = 0x8CE1;
    pub const GL_COLOR_ATTACHMENT2 = 0x8CE2;
    pub const GL_COLOR_ATTACHMENT3 = 0x8CE3;
    pub const GL_COLOR_ATTACHMENT4 = 0x8CE4;
    pub const GL_COLOR_ATTACHMENT5 = 0x8CE5;
    pub const GL_COLOR_ATTACHMENT6 = 0x8CE6;
    pub const GL_COLOR_ATTACHMENT7 = 0x8CE7;
    pub const GL_COLOR_ATTACHMENT8 = 0x8CE8;
    pub const GL_COLOR_ATTACHMENT9 = 0x8CE9;
    pub const GL_COLOR_ATTACHMENT10 = 0x8CEA;
    pub const GL_COLOR_ATTACHMENT11 = 0x8CEB;
    pub const GL_COLOR_ATTACHMENT12 = 0x8CEC;
    pub const GL_COLOR_ATTACHMENT13 = 0x8CED;
    pub const GL_COLOR_ATTACHMENT14 = 0x8CEE;
    pub const GL_COLOR_ATTACHMENT15 = 0x8CEF;
    pub const GL_DEPTH_ATTACHMENT = 0x8D00;
    pub const GL_STENCIL_ATTACHMENT = 0x8D20;
    pub const GL_FRAMEBUFFER = 0x8D40;
    pub const GL_RENDERBUFFER = 0x8D41;
    pub const GL_RENDERBUFFER_WIDTH = 0x8D42;
    pub const GL_RENDERBUFFER_HEIGHT = 0x8D43;
    pub const GL_RENDERBUFFER_INTERNAL_FORMAT = 0x8D44;
    pub const GL_STENCIL_INDEX1 = 0x8D46;
    pub const GL_STENCIL_INDEX4 = 0x8D47;
    pub const GL_STENCIL_INDEX8 = 0x8D48;
    pub const GL_STENCIL_INDEX16 = 0x8D49;
    pub const GL_RENDERBUFFER_RED_SIZE = 0x8D50;
    pub const GL_RENDERBUFFER_GREEN_SIZE = 0x8D51;
    pub const GL_RENDERBUFFER_BLUE_SIZE = 0x8D52;
    pub const GL_RENDERBUFFER_ALPHA_SIZE = 0x8D53;
    pub const GL_RENDERBUFFER_DEPTH_SIZE = 0x8D54;
    pub const GL_RENDERBUFFER_STENCIL_SIZE = 0x8D55;
    pub const GL_FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = 0x8D56;
    pub const GL_MAX_SAMPLES = 0x8D57;
    pub const GL_INDEX = 0x8222;

    pub var glCullFace: fn (mode: GLenum) void = undefined;
    pub var glFrontFace: fn (mode: GLenum) void = undefined;
    pub var glHint: fn (target: GLenum, mode: GLenum) void = undefined;
    pub var glLineWidth: fn (width: GLfloat) void = undefined;
    pub var glPointSize: fn (size: GLfloat) void = undefined;
    pub var glPolygonMode: fn (face: GLenum, mode: GLenum) void = undefined;
    pub var glScissor: fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei) void = undefined;
    pub var glTexParameterf: fn (target: GLenum, pname: GLenum, param: GLfloat) void = undefined;
    pub var glTexParameterfv: fn (target: GLenum, pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glTexParameteri: fn (target: GLenum, pname: GLenum, param: GLint) void = undefined;
    pub var glTexParameteriv: fn (target: GLenum, pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glTexImage1D: fn (target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, border: GLint, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glTexImage2D: fn (target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, border: GLint, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glDrawBuffer: fn (buf: GLenum) void = undefined;
    pub var glClear: fn (mask: GLbitfield) void = undefined;
    pub var glClearColor: fn (red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) void = undefined;
    pub var glClearStencil: fn (s: GLint) void = undefined;
    pub var glClearDepth: fn (depth: GLdouble) void = undefined;
    pub var glStencilMask: fn (mask: GLuint) void = undefined;
    pub var glColorMask: fn (red: GLboolean, green: GLboolean, blue: GLboolean, alpha: GLboolean) void = undefined;
    pub var glDepthMask: fn (flag: GLboolean) void = undefined;
    pub var glDisable: fn (cap: GLenum) void = undefined;
    pub var glEnable: fn (cap: GLenum) void = undefined;
    pub var glFinish: fn () void = undefined;
    pub var glFlush: fn () void = undefined;
    pub var glBlendFunc: fn (sfactor: GLenum, dfactor: GLenum) void = undefined;
    pub var glLogicOp: fn (opcode: GLenum) void = undefined;
    pub var glStencilFunc: fn (func: GLenum, ref: GLint, mask: GLuint) void = undefined;
    pub var glStencilOp: fn (fail: GLenum, zfail: GLenum, zpass: GLenum) void = undefined;
    pub var glDepthFunc: fn (func: GLenum) void = undefined;
    pub var glPixelStoref: fn (pname: GLenum, param: GLfloat) void = undefined;
    pub var glPixelStorei: fn (pname: GLenum, param: GLint) void = undefined;
    pub var glReadBuffer: fn (src: GLenum) void = undefined;
    pub var glReadPixels: fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei, format: GLenum, type: GLenum, pixels: ?*c_void) void = undefined;
    pub var glGetBooleanv: fn (pname: GLenum, data: [*c]GLboolean) void = undefined;
    pub var glGetDoublev: fn (pname: GLenum, data: [*c]GLdouble) void = undefined;
    pub var glGetError: fn () GLenum = undefined;
    pub var glGetFloatv: fn (pname: GLenum, data: [*c]GLfloat) void = undefined;
    pub var glGetIntegerv: fn (pname: GLenum, data: [*c]GLint) void = undefined;
    pub var glGetString: fn (name: GLenum) [*c]const GLubyte = undefined;
    pub var glGetTexImage: fn (target: GLenum, level: GLint, format: GLenum, type: GLenum, pixels: ?*c_void) void = undefined;
    pub var glGetTexParameterfv: fn (target: GLenum, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetTexParameteriv: fn (target: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetTexLevelParameterfv: fn (target: GLenum, level: GLint, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetTexLevelParameteriv: fn (target: GLenum, level: GLint, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glIsEnabled: fn (cap: GLenum) GLboolean = undefined;
    pub var glDepthRange: fn (n: GLdouble, f: GLdouble) void = undefined;
    pub var glViewport: fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei) void = undefined;
    pub var glNewList: fn (list: GLuint, mode: GLenum) void = undefined;
    pub var glEndList: fn () void = undefined;
    pub var glCallList: fn (list: GLuint) void = undefined;
    pub var glCallLists: fn (n: GLsizei, type: GLenum, lists: ?*const c_void) void = undefined;
    pub var glDeleteLists: fn (list: GLuint, range: GLsizei) void = undefined;
    pub var glGenLists: fn (range: GLsizei) GLuint = undefined;
    pub var glListBase: fn (base: GLuint) void = undefined;
    pub var glBegin: fn (mode: GLenum) void = undefined;
    pub var glBitmap: fn (width: GLsizei, height: GLsizei, xorig: GLfloat, yorig: GLfloat, xmove: GLfloat, ymove: GLfloat, bitmap: [*c]const GLubyte) void = undefined;
    pub var glColor3b: fn (red: GLbyte, green: GLbyte, blue: GLbyte) void = undefined;
    pub var glColor3bv: fn (v: [*c]const GLbyte) void = undefined;
    pub var glColor3d: fn (red: GLdouble, green: GLdouble, blue: GLdouble) void = undefined;
    pub var glColor3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glColor3f: fn (red: GLfloat, green: GLfloat, blue: GLfloat) void = undefined;
    pub var glColor3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glColor3i: fn (red: GLint, green: GLint, blue: GLint) void = undefined;
    pub var glColor3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glColor3s: fn (red: GLshort, green: GLshort, blue: GLshort) void = undefined;
    pub var glColor3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glColor3ub: fn (red: GLubyte, green: GLubyte, blue: GLubyte) void = undefined;
    pub var glColor3ubv: fn (v: [*c]const GLubyte) void = undefined;
    pub var glColor3ui: fn (red: GLuint, green: GLuint, blue: GLuint) void = undefined;
    pub var glColor3uiv: fn (v: [*c]const GLuint) void = undefined;
    pub var glColor3us: fn (red: GLushort, green: GLushort, blue: GLushort) void = undefined;
    pub var glColor3usv: fn (v: [*c]const GLushort) void = undefined;
    pub var glColor4b: fn (red: GLbyte, green: GLbyte, blue: GLbyte, alpha: GLbyte) void = undefined;
    pub var glColor4bv: fn (v: [*c]const GLbyte) void = undefined;
    pub var glColor4d: fn (red: GLdouble, green: GLdouble, blue: GLdouble, alpha: GLdouble) void = undefined;
    pub var glColor4dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glColor4f: fn (red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) void = undefined;
    pub var glColor4fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glColor4i: fn (red: GLint, green: GLint, blue: GLint, alpha: GLint) void = undefined;
    pub var glColor4iv: fn (v: [*c]const GLint) void = undefined;
    pub var glColor4s: fn (red: GLshort, green: GLshort, blue: GLshort, alpha: GLshort) void = undefined;
    pub var glColor4sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glColor4ub: fn (red: GLubyte, green: GLubyte, blue: GLubyte, alpha: GLubyte) void = undefined;
    pub var glColor4ubv: fn (v: [*c]const GLubyte) void = undefined;
    pub var glColor4ui: fn (red: GLuint, green: GLuint, blue: GLuint, alpha: GLuint) void = undefined;
    pub var glColor4uiv: fn (v: [*c]const GLuint) void = undefined;
    pub var glColor4us: fn (red: GLushort, green: GLushort, blue: GLushort, alpha: GLushort) void = undefined;
    pub var glColor4usv: fn (v: [*c]const GLushort) void = undefined;
    pub var glEdgeFlag: fn (flag: GLboolean) void = undefined;
    pub var glEdgeFlagv: fn (flag: [*c]const GLboolean) void = undefined;
    pub var glEnd: fn () void = undefined;
    pub var glIndexd: fn (c: GLdouble) void = undefined;
    pub var glIndexdv: fn (c: [*c]const GLdouble) void = undefined;
    pub var glIndexf: fn (c: GLfloat) void = undefined;
    pub var glIndexfv: fn (c: [*c]const GLfloat) void = undefined;
    pub var glIndexi: fn (c: GLint) void = undefined;
    pub var glIndexiv: fn (c: [*c]const GLint) void = undefined;
    pub var glIndexs: fn (c: GLshort) void = undefined;
    pub var glIndexsv: fn (c: [*c]const GLshort) void = undefined;
    pub var glNormal3b: fn (nx: GLbyte, ny: GLbyte, nz: GLbyte) void = undefined;
    pub var glNormal3bv: fn (v: [*c]const GLbyte) void = undefined;
    pub var glNormal3d: fn (nx: GLdouble, ny: GLdouble, nz: GLdouble) void = undefined;
    pub var glNormal3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glNormal3f: fn (nx: GLfloat, ny: GLfloat, nz: GLfloat) void = undefined;
    pub var glNormal3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glNormal3i: fn (nx: GLint, ny: GLint, nz: GLint) void = undefined;
    pub var glNormal3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glNormal3s: fn (nx: GLshort, ny: GLshort, nz: GLshort) void = undefined;
    pub var glNormal3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glRasterPos2d: fn (x: GLdouble, y: GLdouble) void = undefined;
    pub var glRasterPos2dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glRasterPos2f: fn (x: GLfloat, y: GLfloat) void = undefined;
    pub var glRasterPos2fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glRasterPos2i: fn (x: GLint, y: GLint) void = undefined;
    pub var glRasterPos2iv: fn (v: [*c]const GLint) void = undefined;
    pub var glRasterPos2s: fn (x: GLshort, y: GLshort) void = undefined;
    pub var glRasterPos2sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glRasterPos3d: fn (x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glRasterPos3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glRasterPos3f: fn (x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glRasterPos3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glRasterPos3i: fn (x: GLint, y: GLint, z: GLint) void = undefined;
    pub var glRasterPos3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glRasterPos3s: fn (x: GLshort, y: GLshort, z: GLshort) void = undefined;
    pub var glRasterPos3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glRasterPos4d: fn (x: GLdouble, y: GLdouble, z: GLdouble, w: GLdouble) void = undefined;
    pub var glRasterPos4dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glRasterPos4f: fn (x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) void = undefined;
    pub var glRasterPos4fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glRasterPos4i: fn (x: GLint, y: GLint, z: GLint, w: GLint) void = undefined;
    pub var glRasterPos4iv: fn (v: [*c]const GLint) void = undefined;
    pub var glRasterPos4s: fn (x: GLshort, y: GLshort, z: GLshort, w: GLshort) void = undefined;
    pub var glRasterPos4sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glRectd: fn (x1: GLdouble, y1: GLdouble, x2: GLdouble, y2: GLdouble) void = undefined;
    pub var glRectdv: fn (v1: [*c]const GLdouble, v2: [*c]const GLdouble) void = undefined;
    pub var glRectf: fn (x1: GLfloat, y1: GLfloat, x2: GLfloat, y2: GLfloat) void = undefined;
    pub var glRectfv: fn (v1: [*c]const GLfloat, v2: [*c]const GLfloat) void = undefined;
    pub var glRecti: fn (x1: GLint, y1: GLint, x2: GLint, y2: GLint) void = undefined;
    pub var glRectiv: fn (v1: [*c]const GLint, v2: [*c]const GLint) void = undefined;
    pub var glRects: fn (x1: GLshort, y1: GLshort, x2: GLshort, y2: GLshort) void = undefined;
    pub var glRectsv: fn (v1: [*c]const GLshort, v2: [*c]const GLshort) void = undefined;
    pub var glTexCoord1d: fn (s: GLdouble) void = undefined;
    pub var glTexCoord1dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glTexCoord1f: fn (s: GLfloat) void = undefined;
    pub var glTexCoord1fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glTexCoord1i: fn (s: GLint) void = undefined;
    pub var glTexCoord1iv: fn (v: [*c]const GLint) void = undefined;
    pub var glTexCoord1s: fn (s: GLshort) void = undefined;
    pub var glTexCoord1sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glTexCoord2d: fn (s: GLdouble, t: GLdouble) void = undefined;
    pub var glTexCoord2dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glTexCoord2f: fn (s: GLfloat, t: GLfloat) void = undefined;
    pub var glTexCoord2fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glTexCoord2i: fn (s: GLint, t: GLint) void = undefined;
    pub var glTexCoord2iv: fn (v: [*c]const GLint) void = undefined;
    pub var glTexCoord2s: fn (s: GLshort, t: GLshort) void = undefined;
    pub var glTexCoord2sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glTexCoord3d: fn (s: GLdouble, t: GLdouble, r: GLdouble) void = undefined;
    pub var glTexCoord3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glTexCoord3f: fn (s: GLfloat, t: GLfloat, r: GLfloat) void = undefined;
    pub var glTexCoord3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glTexCoord3i: fn (s: GLint, t: GLint, r: GLint) void = undefined;
    pub var glTexCoord3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glTexCoord3s: fn (s: GLshort, t: GLshort, r: GLshort) void = undefined;
    pub var glTexCoord3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glTexCoord4d: fn (s: GLdouble, t: GLdouble, r: GLdouble, q: GLdouble) void = undefined;
    pub var glTexCoord4dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glTexCoord4f: fn (s: GLfloat, t: GLfloat, r: GLfloat, q: GLfloat) void = undefined;
    pub var glTexCoord4fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glTexCoord4i: fn (s: GLint, t: GLint, r: GLint, q: GLint) void = undefined;
    pub var glTexCoord4iv: fn (v: [*c]const GLint) void = undefined;
    pub var glTexCoord4s: fn (s: GLshort, t: GLshort, r: GLshort, q: GLshort) void = undefined;
    pub var glTexCoord4sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glVertex2d: fn (x: GLdouble, y: GLdouble) void = undefined;
    pub var glVertex2dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glVertex2f: fn (x: GLfloat, y: GLfloat) void = undefined;
    pub var glVertex2fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glVertex2i: fn (x: GLint, y: GLint) void = undefined;
    pub var glVertex2iv: fn (v: [*c]const GLint) void = undefined;
    pub var glVertex2s: fn (x: GLshort, y: GLshort) void = undefined;
    pub var glVertex2sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glVertex3d: fn (x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glVertex3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glVertex3f: fn (x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glVertex3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glVertex3i: fn (x: GLint, y: GLint, z: GLint) void = undefined;
    pub var glVertex3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glVertex3s: fn (x: GLshort, y: GLshort, z: GLshort) void = undefined;
    pub var glVertex3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glVertex4d: fn (x: GLdouble, y: GLdouble, z: GLdouble, w: GLdouble) void = undefined;
    pub var glVertex4dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glVertex4f: fn (x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) void = undefined;
    pub var glVertex4fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glVertex4i: fn (x: GLint, y: GLint, z: GLint, w: GLint) void = undefined;
    pub var glVertex4iv: fn (v: [*c]const GLint) void = undefined;
    pub var glVertex4s: fn (x: GLshort, y: GLshort, z: GLshort, w: GLshort) void = undefined;
    pub var glVertex4sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glClipPlane: fn (plane: GLenum, equation: [*c]const GLdouble) void = undefined;
    pub var glColorMaterial: fn (face: GLenum, mode: GLenum) void = undefined;
    pub var glFogf: fn (pname: GLenum, param: GLfloat) void = undefined;
    pub var glFogfv: fn (pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glFogi: fn (pname: GLenum, param: GLint) void = undefined;
    pub var glFogiv: fn (pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glLightf: fn (light: GLenum, pname: GLenum, param: GLfloat) void = undefined;
    pub var glLightfv: fn (light: GLenum, pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glLighti: fn (light: GLenum, pname: GLenum, param: GLint) void = undefined;
    pub var glLightiv: fn (light: GLenum, pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glLightModelf: fn (pname: GLenum, param: GLfloat) void = undefined;
    pub var glLightModelfv: fn (pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glLightModeli: fn (pname: GLenum, param: GLint) void = undefined;
    pub var glLightModeliv: fn (pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glLineStipple: fn (factor: GLint, pattern: GLushort) void = undefined;
    pub var glMaterialf: fn (face: GLenum, pname: GLenum, param: GLfloat) void = undefined;
    pub var glMaterialfv: fn (face: GLenum, pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glMateriali: fn (face: GLenum, pname: GLenum, param: GLint) void = undefined;
    pub var glMaterialiv: fn (face: GLenum, pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glPolygonStipple: fn (mask: [*c]const GLubyte) void = undefined;
    pub var glShadeModel: fn (mode: GLenum) void = undefined;
    pub var glTexEnvf: fn (target: GLenum, pname: GLenum, param: GLfloat) void = undefined;
    pub var glTexEnvfv: fn (target: GLenum, pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glTexEnvi: fn (target: GLenum, pname: GLenum, param: GLint) void = undefined;
    pub var glTexEnviv: fn (target: GLenum, pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glTexGend: fn (coord: GLenum, pname: GLenum, param: GLdouble) void = undefined;
    pub var glTexGendv: fn (coord: GLenum, pname: GLenum, params: [*c]const GLdouble) void = undefined;
    pub var glTexGenf: fn (coord: GLenum, pname: GLenum, param: GLfloat) void = undefined;
    pub var glTexGenfv: fn (coord: GLenum, pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glTexGeni: fn (coord: GLenum, pname: GLenum, param: GLint) void = undefined;
    pub var glTexGeniv: fn (coord: GLenum, pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glFeedbackBuffer: fn (size: GLsizei, type: GLenum, buffer: [*c]GLfloat) void = undefined;
    pub var glSelectBuffer: fn (size: GLsizei, buffer: [*c]GLuint) void = undefined;
    pub var glRenderMode: fn (mode: GLenum) GLint = undefined;
    pub var glInitNames: fn () void = undefined;
    pub var glLoadName: fn (name: GLuint) void = undefined;
    pub var glPassThrough: fn (token: GLfloat) void = undefined;
    pub var glPopName: fn () void = undefined;
    pub var glPushName: fn (name: GLuint) void = undefined;
    pub var glClearAccum: fn (red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) void = undefined;
    pub var glClearIndex: fn (c: GLfloat) void = undefined;
    pub var glIndexMask: fn (mask: GLuint) void = undefined;
    pub var glAccum: fn (op: GLenum, value: GLfloat) void = undefined;
    pub var glPopAttrib: fn () void = undefined;
    pub var glPushAttrib: fn (mask: GLbitfield) void = undefined;
    pub var glMap1d: fn (target: GLenum, u1: GLdouble, u2: GLdouble, stride: GLint, order: GLint, points: [*c]const GLdouble) void = undefined;
    pub var glMap1f: fn (target: GLenum, u1: GLfloat, u2: GLfloat, stride: GLint, order: GLint, points: [*c]const GLfloat) void = undefined;
    pub var glMap2d: fn (target: GLenum, u1: GLdouble, u2: GLdouble, ustride: GLint, uorder: GLint, v1: GLdouble, v2: GLdouble, vstride: GLint, vorder: GLint, points: [*c]const GLdouble) void = undefined;
    pub var glMap2f: fn (target: GLenum, u1: GLfloat, u2: GLfloat, ustride: GLint, uorder: GLint, v1: GLfloat, v2: GLfloat, vstride: GLint, vorder: GLint, points: [*c]const GLfloat) void = undefined;
    pub var glMapGrid1d: fn (un: GLint, u1: GLdouble, u2: GLdouble) void = undefined;
    pub var glMapGrid1f: fn (un: GLint, u1: GLfloat, u2: GLfloat) void = undefined;
    pub var glMapGrid2d: fn (un: GLint, u1: GLdouble, u2: GLdouble, vn: GLint, v1: GLdouble, v2: GLdouble) void = undefined;
    pub var glMapGrid2f: fn (un: GLint, u1: GLfloat, u2: GLfloat, vn: GLint, v1: GLfloat, v2: GLfloat) void = undefined;
    pub var glEvalCoord1d: fn (u: GLdouble) void = undefined;
    pub var glEvalCoord1dv: fn (u: [*c]const GLdouble) void = undefined;
    pub var glEvalCoord1f: fn (u: GLfloat) void = undefined;
    pub var glEvalCoord1fv: fn (u: [*c]const GLfloat) void = undefined;
    pub var glEvalCoord2d: fn (u: GLdouble, v: GLdouble) void = undefined;
    pub var glEvalCoord2dv: fn (u: [*c]const GLdouble) void = undefined;
    pub var glEvalCoord2f: fn (u: GLfloat, v: GLfloat) void = undefined;
    pub var glEvalCoord2fv: fn (u: [*c]const GLfloat) void = undefined;
    pub var glEvalMesh1: fn (mode: GLenum, i1: GLint, i2: GLint) void = undefined;
    pub var glEvalPoint1: fn (i: GLint) void = undefined;
    pub var glEvalMesh2: fn (mode: GLenum, i1: GLint, i2: GLint, j1: GLint, j2: GLint) void = undefined;
    pub var glEvalPoint2: fn (i: GLint, j: GLint) void = undefined;
    pub var glAlphaFunc: fn (func: GLenum, ref: GLfloat) void = undefined;
    pub var glPixelZoom: fn (xfactor: GLfloat, yfactor: GLfloat) void = undefined;
    pub var glPixelTransferf: fn (pname: GLenum, param: GLfloat) void = undefined;
    pub var glPixelTransferi: fn (pname: GLenum, param: GLint) void = undefined;
    pub var glPixelMapfv: fn (map: GLenum, mapsize: GLsizei, values: [*c]const GLfloat) void = undefined;
    pub var glPixelMapuiv: fn (map: GLenum, mapsize: GLsizei, values: [*c]const GLuint) void = undefined;
    pub var glPixelMapusv: fn (map: GLenum, mapsize: GLsizei, values: [*c]const GLushort) void = undefined;
    pub var glCopyPixels: fn (x: GLint, y: GLint, width: GLsizei, height: GLsizei, type: GLenum) void = undefined;
    pub var glDrawPixels: fn (width: GLsizei, height: GLsizei, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glGetClipPlane: fn (plane: GLenum, equation: [*c]GLdouble) void = undefined;
    pub var glGetLightfv: fn (light: GLenum, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetLightiv: fn (light: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetMapdv: fn (target: GLenum, query: GLenum, v: [*c]GLdouble) void = undefined;
    pub var glGetMapfv: fn (target: GLenum, query: GLenum, v: [*c]GLfloat) void = undefined;
    pub var glGetMapiv: fn (target: GLenum, query: GLenum, v: [*c]GLint) void = undefined;
    pub var glGetMaterialfv: fn (face: GLenum, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetMaterialiv: fn (face: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetPixelMapfv: fn (map: GLenum, values: [*c]GLfloat) void = undefined;
    pub var glGetPixelMapuiv: fn (map: GLenum, values: [*c]GLuint) void = undefined;
    pub var glGetPixelMapusv: fn (map: GLenum, values: [*c]GLushort) void = undefined;
    pub var glGetPolygonStipple: fn (mask: [*c]GLubyte) void = undefined;
    pub var glGetTexEnvfv: fn (target: GLenum, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetTexEnviv: fn (target: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetTexGendv: fn (coord: GLenum, pname: GLenum, params: [*c]GLdouble) void = undefined;
    pub var glGetTexGenfv: fn (coord: GLenum, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetTexGeniv: fn (coord: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glIsList: fn (list: GLuint) GLboolean = undefined;
    pub var glFrustum: fn (left: GLdouble, right: GLdouble, bottom: GLdouble, top: GLdouble, zNear: GLdouble, zFar: GLdouble) void = undefined;
    pub var glLoadIdentity: fn () void = undefined;
    pub var glLoadMatrixf: fn (m: [*c]const GLfloat) void = undefined;
    pub var glLoadMatrixd: fn (m: [*c]const GLdouble) void = undefined;
    pub var glMatrixMode: fn (mode: GLenum) void = undefined;
    pub var glMultMatrixf: fn (m: [*c]const GLfloat) void = undefined;
    pub var glMultMatrixd: fn (m: [*c]const GLdouble) void = undefined;
    pub var glOrtho: fn (left: GLdouble, right: GLdouble, bottom: GLdouble, top: GLdouble, zNear: GLdouble, zFar: GLdouble) void = undefined;
    pub var glPopMatrix: fn () void = undefined;
    pub var glPushMatrix: fn () void = undefined;
    pub var glRotated: fn (angle: GLdouble, x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glRotatef: fn (angle: GLfloat, x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glScaled: fn (x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glScalef: fn (x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glTranslated: fn (x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glTranslatef: fn (x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glDrawArrays: fn (mode: GLenum, first: GLint, count: GLsizei) void = undefined;
    pub var glDrawElements: fn (mode: GLenum, count: GLsizei, type: GLenum, indices: ?*const c_void) void = undefined;
    pub var glGetPointerv: fn (pname: GLenum, params: [*c]?*c_void) void = undefined;
    pub var glPolygonOffset: fn (factor: GLfloat, units: GLfloat) void = undefined;
    pub var glCopyTexImage1D: fn (target: GLenum, level: GLint, internalformat: GLenum, x: GLint, y: GLint, width: GLsizei, border: GLint) void = undefined;
    pub var glCopyTexImage2D: fn (target: GLenum, level: GLint, internalformat: GLenum, x: GLint, y: GLint, width: GLsizei, height: GLsizei, border: GLint) void = undefined;
    pub var glCopyTexSubImage1D: fn (target: GLenum, level: GLint, xoffset: GLint, x: GLint, y: GLint, width: GLsizei) void = undefined;
    pub var glCopyTexSubImage2D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) void = undefined;
    pub var glTexSubImage1D: fn (target: GLenum, level: GLint, xoffset: GLint, width: GLsizei, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glTexSubImage2D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glBindTexture: fn (target: GLenum, texture: GLuint) void = undefined;
    pub var glDeleteTextures: fn (n: GLsizei, textures: [*c]const GLuint) void = undefined;
    pub var glGenTextures: fn (n: GLsizei, textures: [*c]GLuint) void = undefined;
    pub var glIsTexture: fn (texture: GLuint) GLboolean = undefined;
    pub var glArrayElement: fn (i: GLint) void = undefined;
    pub var glColorPointer: fn (size: GLint, type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glDisableClientState: fn (array: GLenum) void = undefined;
    pub var glEdgeFlagPointer: fn (stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glEnableClientState: fn (array: GLenum) void = undefined;
    pub var glIndexPointer: fn (type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glInterleavedArrays: fn (format: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glNormalPointer: fn (type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glTexCoordPointer: fn (size: GLint, type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glVertexPointer: fn (size: GLint, type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glAreTexturesResident: fn (n: GLsizei, textures: [*c]const GLuint, residences: [*c]GLboolean) GLboolean = undefined;
    pub var glPrioritizeTextures: fn (n: GLsizei, textures: [*c]const GLuint, priorities: [*c]const GLfloat) void = undefined;
    pub var glIndexub: fn (c: GLubyte) void = undefined;
    pub var glIndexubv: fn (c: [*c]const GLubyte) void = undefined;
    pub var glPopClientAttrib: fn () void = undefined;
    pub var glPushClientAttrib: fn (mask: GLbitfield) void = undefined;
    pub var glDrawRangeElements: fn (mode: GLenum, start: GLuint, end: GLuint, count: GLsizei, type: GLenum, indices: ?*const c_void) void = undefined;
    pub var glTexImage3D: fn (target: GLenum, level: GLint, internalformat: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glTexSubImage3D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, type: GLenum, pixels: ?*const c_void) void = undefined;
    pub var glCopyTexSubImage3D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, x: GLint, y: GLint, width: GLsizei, height: GLsizei) void = undefined;
    pub var glActiveTexture: fn (texture: GLenum) void = undefined;
    pub var glSampleCoverage: fn (value: GLfloat, invert: GLboolean) void = undefined;
    pub var glCompressedTexImage3D: fn (target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, depth: GLsizei, border: GLint, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glCompressedTexImage2D: fn (target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, height: GLsizei, border: GLint, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glCompressedTexImage1D: fn (target: GLenum, level: GLint, internalformat: GLenum, width: GLsizei, border: GLint, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glCompressedTexSubImage3D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, zoffset: GLint, width: GLsizei, height: GLsizei, depth: GLsizei, format: GLenum, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glCompressedTexSubImage2D: fn (target: GLenum, level: GLint, xoffset: GLint, yoffset: GLint, width: GLsizei, height: GLsizei, format: GLenum, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glCompressedTexSubImage1D: fn (target: GLenum, level: GLint, xoffset: GLint, width: GLsizei, format: GLenum, imageSize: GLsizei, data: ?*const c_void) void = undefined;
    pub var glGetCompressedTexImage: fn (target: GLenum, level: GLint, img: ?*c_void) void = undefined;
    pub var glClientActiveTexture: fn (texture: GLenum) void = undefined;
    pub var glMultiTexCoord1d: fn (target: GLenum, s: GLdouble) void = undefined;
    pub var glMultiTexCoord1dv: fn (target: GLenum, v: [*c]const GLdouble) void = undefined;
    pub var glMultiTexCoord1f: fn (target: GLenum, s: GLfloat) void = undefined;
    pub var glMultiTexCoord1fv: fn (target: GLenum, v: [*c]const GLfloat) void = undefined;
    pub var glMultiTexCoord1i: fn (target: GLenum, s: GLint) void = undefined;
    pub var glMultiTexCoord1iv: fn (target: GLenum, v: [*c]const GLint) void = undefined;
    pub var glMultiTexCoord1s: fn (target: GLenum, s: GLshort) void = undefined;
    pub var glMultiTexCoord1sv: fn (target: GLenum, v: [*c]const GLshort) void = undefined;
    pub var glMultiTexCoord2d: fn (target: GLenum, s: GLdouble, t: GLdouble) void = undefined;
    pub var glMultiTexCoord2dv: fn (target: GLenum, v: [*c]const GLdouble) void = undefined;
    pub var glMultiTexCoord2f: fn (target: GLenum, s: GLfloat, t: GLfloat) void = undefined;
    pub var glMultiTexCoord2fv: fn (target: GLenum, v: [*c]const GLfloat) void = undefined;
    pub var glMultiTexCoord2i: fn (target: GLenum, s: GLint, t: GLint) void = undefined;
    pub var glMultiTexCoord2iv: fn (target: GLenum, v: [*c]const GLint) void = undefined;
    pub var glMultiTexCoord2s: fn (target: GLenum, s: GLshort, t: GLshort) void = undefined;
    pub var glMultiTexCoord2sv: fn (target: GLenum, v: [*c]const GLshort) void = undefined;
    pub var glMultiTexCoord3d: fn (target: GLenum, s: GLdouble, t: GLdouble, r: GLdouble) void = undefined;
    pub var glMultiTexCoord3dv: fn (target: GLenum, v: [*c]const GLdouble) void = undefined;
    pub var glMultiTexCoord3f: fn (target: GLenum, s: GLfloat, t: GLfloat, r: GLfloat) void = undefined;
    pub var glMultiTexCoord3fv: fn (target: GLenum, v: [*c]const GLfloat) void = undefined;
    pub var glMultiTexCoord3i: fn (target: GLenum, s: GLint, t: GLint, r: GLint) void = undefined;
    pub var glMultiTexCoord3iv: fn (target: GLenum, v: [*c]const GLint) void = undefined;
    pub var glMultiTexCoord3s: fn (target: GLenum, s: GLshort, t: GLshort, r: GLshort) void = undefined;
    pub var glMultiTexCoord3sv: fn (target: GLenum, v: [*c]const GLshort) void = undefined;
    pub var glMultiTexCoord4d: fn (target: GLenum, s: GLdouble, t: GLdouble, r: GLdouble, q: GLdouble) void = undefined;
    pub var glMultiTexCoord4dv: fn (target: GLenum, v: [*c]const GLdouble) void = undefined;
    pub var glMultiTexCoord4f: fn (target: GLenum, s: GLfloat, t: GLfloat, r: GLfloat, q: GLfloat) void = undefined;
    pub var glMultiTexCoord4fv: fn (target: GLenum, v: [*c]const GLfloat) void = undefined;
    pub var glMultiTexCoord4i: fn (target: GLenum, s: GLint, t: GLint, r: GLint, q: GLint) void = undefined;
    pub var glMultiTexCoord4iv: fn (target: GLenum, v: [*c]const GLint) void = undefined;
    pub var glMultiTexCoord4s: fn (target: GLenum, s: GLshort, t: GLshort, r: GLshort, q: GLshort) void = undefined;
    pub var glMultiTexCoord4sv: fn (target: GLenum, v: [*c]const GLshort) void = undefined;
    pub var glLoadTransposeMatrixf: fn (m: [*c]const GLfloat) void = undefined;
    pub var glLoadTransposeMatrixd: fn (m: [*c]const GLdouble) void = undefined;
    pub var glMultTransposeMatrixf: fn (m: [*c]const GLfloat) void = undefined;
    pub var glMultTransposeMatrixd: fn (m: [*c]const GLdouble) void = undefined;
    pub var glBlendFuncSeparate: fn (sfactorRGB: GLenum, dfactorRGB: GLenum, sfactorAlpha: GLenum, dfactorAlpha: GLenum) void = undefined;
    pub var glMultiDrawArrays: fn (mode: GLenum, first: [*c]const GLint, count: [*c]const GLsizei, drawcount: GLsizei) void = undefined;
    pub var glMultiDrawElements: fn (mode: GLenum, count: [*c]const GLsizei, type: GLenum, indices: [*c]const ?*const c_void, drawcount: GLsizei) void = undefined;
    pub var glPointParameterf: fn (pname: GLenum, param: GLfloat) void = undefined;
    pub var glPointParameterfv: fn (pname: GLenum, params: [*c]const GLfloat) void = undefined;
    pub var glPointParameteri: fn (pname: GLenum, param: GLint) void = undefined;
    pub var glPointParameteriv: fn (pname: GLenum, params: [*c]const GLint) void = undefined;
    pub var glFogCoordf: fn (coord: GLfloat) void = undefined;
    pub var glFogCoordfv: fn (coord: [*c]const GLfloat) void = undefined;
    pub var glFogCoordd: fn (coord: GLdouble) void = undefined;
    pub var glFogCoorddv: fn (coord: [*c]const GLdouble) void = undefined;
    pub var glFogCoordPointer: fn (type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glSecondaryColor3b: fn (red: GLbyte, green: GLbyte, blue: GLbyte) void = undefined;
    pub var glSecondaryColor3bv: fn (v: [*c]const GLbyte) void = undefined;
    pub var glSecondaryColor3d: fn (red: GLdouble, green: GLdouble, blue: GLdouble) void = undefined;
    pub var glSecondaryColor3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glSecondaryColor3f: fn (red: GLfloat, green: GLfloat, blue: GLfloat) void = undefined;
    pub var glSecondaryColor3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glSecondaryColor3i: fn (red: GLint, green: GLint, blue: GLint) void = undefined;
    pub var glSecondaryColor3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glSecondaryColor3s: fn (red: GLshort, green: GLshort, blue: GLshort) void = undefined;
    pub var glSecondaryColor3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glSecondaryColor3ub: fn (red: GLubyte, green: GLubyte, blue: GLubyte) void = undefined;
    pub var glSecondaryColor3ubv: fn (v: [*c]const GLubyte) void = undefined;
    pub var glSecondaryColor3ui: fn (red: GLuint, green: GLuint, blue: GLuint) void = undefined;
    pub var glSecondaryColor3uiv: fn (v: [*c]const GLuint) void = undefined;
    pub var glSecondaryColor3us: fn (red: GLushort, green: GLushort, blue: GLushort) void = undefined;
    pub var glSecondaryColor3usv: fn (v: [*c]const GLushort) void = undefined;
    pub var glSecondaryColorPointer: fn (size: GLint, type: GLenum, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glWindowPos2d: fn (x: GLdouble, y: GLdouble) void = undefined;
    pub var glWindowPos2dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glWindowPos2f: fn (x: GLfloat, y: GLfloat) void = undefined;
    pub var glWindowPos2fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glWindowPos2i: fn (x: GLint, y: GLint) void = undefined;
    pub var glWindowPos2iv: fn (v: [*c]const GLint) void = undefined;
    pub var glWindowPos2s: fn (x: GLshort, y: GLshort) void = undefined;
    pub var glWindowPos2sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glWindowPos3d: fn (x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glWindowPos3dv: fn (v: [*c]const GLdouble) void = undefined;
    pub var glWindowPos3f: fn (x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glWindowPos3fv: fn (v: [*c]const GLfloat) void = undefined;
    pub var glWindowPos3i: fn (x: GLint, y: GLint, z: GLint) void = undefined;
    pub var glWindowPos3iv: fn (v: [*c]const GLint) void = undefined;
    pub var glWindowPos3s: fn (x: GLshort, y: GLshort, z: GLshort) void = undefined;
    pub var glWindowPos3sv: fn (v: [*c]const GLshort) void = undefined;
    pub var glBlendColor: fn (red: GLfloat, green: GLfloat, blue: GLfloat, alpha: GLfloat) void = undefined;
    pub var glBlendEquation: fn (mode: GLenum) void = undefined;
    pub var glGenQueries: fn (n: GLsizei, ids: [*c]GLuint) void = undefined;
    pub var glDeleteQueries: fn (n: GLsizei, ids: [*c]const GLuint) void = undefined;
    pub var glIsQuery: fn (id: GLuint) GLboolean = undefined;
    pub var glBeginQuery: fn (target: GLenum, id: GLuint) void = undefined;
    pub var glEndQuery: fn (target: GLenum) void = undefined;
    pub var glGetQueryiv: fn (target: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetQueryObjectiv: fn (id: GLuint, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetQueryObjectuiv: fn (id: GLuint, pname: GLenum, params: [*c]GLuint) void = undefined;
    pub var glBindBuffer: fn (target: GLenum, buffer: GLuint) void = undefined;
    pub var glDeleteBuffers: fn (n: GLsizei, buffers: [*c]const GLuint) void = undefined;
    pub var glGenBuffers: fn (n: GLsizei, buffers: [*c]GLuint) void = undefined;
    pub var glIsBuffer: fn (buffer: GLuint) GLboolean = undefined;
    pub var glBufferData: fn (target: GLenum, size: GLsizeiptr, data: ?*const c_void, usage: GLenum) void = undefined;
    pub var glBufferSubData: fn (target: GLenum, offset: GLintptr, size: GLsizeiptr, data: ?*const c_void) void = undefined;
    pub var glGetBufferSubData: fn (target: GLenum, offset: GLintptr, size: GLsizeiptr, data: ?*c_void) void = undefined;
    pub var glMapBuffer: fn (target: GLenum, access: GLenum) ?*c_void = undefined;
    pub var glUnmapBuffer: fn (target: GLenum) GLboolean = undefined;
    pub var glGetBufferParameteriv: fn (target: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetBufferPointerv: fn (target: GLenum, pname: GLenum, params: [*c]?*c_void) void = undefined;
    pub var glBlendEquationSeparate: fn (modeRGB: GLenum, modeAlpha: GLenum) void = undefined;
    pub var glDrawBuffers: fn (n: GLsizei, bufs: [*c]const GLenum) void = undefined;
    pub var glStencilOpSeparate: fn (face: GLenum, sfail: GLenum, dpfail: GLenum, dppass: GLenum) void = undefined;
    pub var glStencilFuncSeparate: fn (face: GLenum, func: GLenum, ref: GLint, mask: GLuint) void = undefined;
    pub var glStencilMaskSeparate: fn (face: GLenum, mask: GLuint) void = undefined;
    pub var glAttachShader: fn (program: GLuint, shader: GLuint) void = undefined;
    pub var glBindAttribLocation: fn (program: GLuint, index: GLuint, name: [*c]const GLchar) void = undefined;
    pub var glCompileShader: fn (shader: GLuint) void = undefined;
    pub var glCreateProgram: fn () GLuint = undefined;
    pub var glCreateShader: fn (type: GLenum) GLuint = undefined;
    pub var glDeleteProgram: fn (program: GLuint) void = undefined;
    pub var glDeleteShader: fn (shader: GLuint) void = undefined;
    pub var glDetachShader: fn (program: GLuint, shader: GLuint) void = undefined;
    pub var glDisableVertexAttribArray: fn (index: GLuint) void = undefined;
    pub var glEnableVertexAttribArray: fn (index: GLuint) void = undefined;
    pub var glGetActiveAttrib: fn (program: GLuint, index: GLuint, bufSize: GLsizei, length: [*c]GLsizei, size: [*c]GLint, type: [*c]GLenum, name: [*c]GLchar) void = undefined;
    pub var glGetActiveUniform: fn (program: GLuint, index: GLuint, bufSize: GLsizei, length: [*c]GLsizei, size: [*c]GLint, type: [*c]GLenum, name: [*c]GLchar) void = undefined;
    pub var glGetAttachedShaders: fn (program: GLuint, maxCount: GLsizei, count: [*c]GLsizei, shaders: [*c]GLuint) void = undefined;
    pub var glGetAttribLocation: fn (program: GLuint, name: [*c]const GLchar) GLint = undefined;
    pub var glGetProgramiv: fn (program: GLuint, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetProgramInfoLog: fn (program: GLuint, bufSize: GLsizei, length: [*c]GLsizei, infoLog: [*c]GLchar) void = undefined;
    pub var glGetShaderiv: fn (shader: GLuint, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetShaderInfoLog: fn (shader: GLuint, bufSize: GLsizei, length: [*c]GLsizei, infoLog: [*c]GLchar) void = undefined;
    pub var glGetShaderSource: fn (shader: GLuint, bufSize: GLsizei, length: [*c]GLsizei, source: [*c]GLchar) void = undefined;
    pub var glGetUniformLocation: fn (program: GLuint, name: [*c]const GLchar) GLint = undefined;
    pub var glGetUniformfv: fn (program: GLuint, location: GLint, params: [*c]GLfloat) void = undefined;
    pub var glGetUniformiv: fn (program: GLuint, location: GLint, params: [*c]GLint) void = undefined;
    pub var glGetVertexAttribdv: fn (index: GLuint, pname: GLenum, params: [*c]GLdouble) void = undefined;
    pub var glGetVertexAttribfv: fn (index: GLuint, pname: GLenum, params: [*c]GLfloat) void = undefined;
    pub var glGetVertexAttribiv: fn (index: GLuint, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGetVertexAttribPointerv: fn (index: GLuint, pname: GLenum, pointer: [*c]?*c_void) void = undefined;
    pub var glIsProgram: fn (program: GLuint) GLboolean = undefined;
    pub var glIsShader: fn (shader: GLuint) GLboolean = undefined;
    pub var glLinkProgram: fn (program: GLuint) void = undefined;
    pub var glShaderSource: fn (shader: GLuint, count: GLsizei, string: [*c]const [*c]const GLchar, length: [*c]const GLint) void = undefined;
    pub var glUseProgram: fn (program: GLuint) void = undefined;
    pub var glUniform1f: fn (location: GLint, v0: GLfloat) void = undefined;
    pub var glUniform2f: fn (location: GLint, v0: GLfloat, v1: GLfloat) void = undefined;
    pub var glUniform3f: fn (location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat) void = undefined;
    pub var glUniform4f: fn (location: GLint, v0: GLfloat, v1: GLfloat, v2: GLfloat, v3: GLfloat) void = undefined;
    pub var glUniform1i: fn (location: GLint, v0: GLint) void = undefined;
    pub var glUniform2i: fn (location: GLint, v0: GLint, v1: GLint) void = undefined;
    pub var glUniform3i: fn (location: GLint, v0: GLint, v1: GLint, v2: GLint) void = undefined;
    pub var glUniform4i: fn (location: GLint, v0: GLint, v1: GLint, v2: GLint, v3: GLint) void = undefined;
    pub var glUniform1fv: fn (location: GLint, count: GLsizei, value: [*c]const GLfloat) void = undefined;
    pub var glUniform2fv: fn (location: GLint, count: GLsizei, value: [*c]const GLfloat) void = undefined;
    pub var glUniform3fv: fn (location: GLint, count: GLsizei, value: [*c]const GLfloat) void = undefined;
    pub var glUniform4fv: fn (location: GLint, count: GLsizei, value: [*c]const GLfloat) void = undefined;
    pub var glUniform1iv: fn (location: GLint, count: GLsizei, value: [*c]const GLint) void = undefined;
    pub var glUniform2iv: fn (location: GLint, count: GLsizei, value: [*c]const GLint) void = undefined;
    pub var glUniform3iv: fn (location: GLint, count: GLsizei, value: [*c]const GLint) void = undefined;
    pub var glUniform4iv: fn (location: GLint, count: GLsizei, value: [*c]const GLint) void = undefined;
    pub var glUniformMatrix2fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix3fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix4fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glValidateProgram: fn (program: GLuint) void = undefined;
    pub var glVertexAttrib1d: fn (index: GLuint, x: GLdouble) void = undefined;
    pub var glVertexAttrib1dv: fn (index: GLuint, v: [*c]const GLdouble) void = undefined;
    pub var glVertexAttrib1f: fn (index: GLuint, x: GLfloat) void = undefined;
    pub var glVertexAttrib1fv: fn (index: GLuint, v: [*c]const GLfloat) void = undefined;
    pub var glVertexAttrib1s: fn (index: GLuint, x: GLshort) void = undefined;
    pub var glVertexAttrib1sv: fn (index: GLuint, v: [*c]const GLshort) void = undefined;
    pub var glVertexAttrib2d: fn (index: GLuint, x: GLdouble, y: GLdouble) void = undefined;
    pub var glVertexAttrib2dv: fn (index: GLuint, v: [*c]const GLdouble) void = undefined;
    pub var glVertexAttrib2f: fn (index: GLuint, x: GLfloat, y: GLfloat) void = undefined;
    pub var glVertexAttrib2fv: fn (index: GLuint, v: [*c]const GLfloat) void = undefined;
    pub var glVertexAttrib2s: fn (index: GLuint, x: GLshort, y: GLshort) void = undefined;
    pub var glVertexAttrib2sv: fn (index: GLuint, v: [*c]const GLshort) void = undefined;
    pub var glVertexAttrib3d: fn (index: GLuint, x: GLdouble, y: GLdouble, z: GLdouble) void = undefined;
    pub var glVertexAttrib3dv: fn (index: GLuint, v: [*c]const GLdouble) void = undefined;
    pub var glVertexAttrib3f: fn (index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat) void = undefined;
    pub var glVertexAttrib3fv: fn (index: GLuint, v: [*c]const GLfloat) void = undefined;
    pub var glVertexAttrib3s: fn (index: GLuint, x: GLshort, y: GLshort, z: GLshort) void = undefined;
    pub var glVertexAttrib3sv: fn (index: GLuint, v: [*c]const GLshort) void = undefined;
    pub var glVertexAttrib4Nbv: fn (index: GLuint, v: [*c]const GLbyte) void = undefined;
    pub var glVertexAttrib4Niv: fn (index: GLuint, v: [*c]const GLint) void = undefined;
    pub var glVertexAttrib4Nsv: fn (index: GLuint, v: [*c]const GLshort) void = undefined;
    pub var glVertexAttrib4Nub: fn (index: GLuint, x: GLubyte, y: GLubyte, z: GLubyte, w: GLubyte) void = undefined;
    pub var glVertexAttrib4Nubv: fn (index: GLuint, v: [*c]const GLubyte) void = undefined;
    pub var glVertexAttrib4Nuiv: fn (index: GLuint, v: [*c]const GLuint) void = undefined;
    pub var glVertexAttrib4Nusv: fn (index: GLuint, v: [*c]const GLushort) void = undefined;
    pub var glVertexAttrib4bv: fn (index: GLuint, v: [*c]const GLbyte) void = undefined;
    pub var glVertexAttrib4d: fn (index: GLuint, x: GLdouble, y: GLdouble, z: GLdouble, w: GLdouble) void = undefined;
    pub var glVertexAttrib4dv: fn (index: GLuint, v: [*c]const GLdouble) void = undefined;
    pub var glVertexAttrib4f: fn (index: GLuint, x: GLfloat, y: GLfloat, z: GLfloat, w: GLfloat) void = undefined;
    pub var glVertexAttrib4fv: fn (index: GLuint, v: [*c]const GLfloat) void = undefined;
    pub var glVertexAttrib4iv: fn (index: GLuint, v: [*c]const GLint) void = undefined;
    pub var glVertexAttrib4s: fn (index: GLuint, x: GLshort, y: GLshort, z: GLshort, w: GLshort) void = undefined;
    pub var glVertexAttrib4sv: fn (index: GLuint, v: [*c]const GLshort) void = undefined;
    pub var glVertexAttrib4ubv: fn (index: GLuint, v: [*c]const GLubyte) void = undefined;
    pub var glVertexAttrib4uiv: fn (index: GLuint, v: [*c]const GLuint) void = undefined;
    pub var glVertexAttrib4usv: fn (index: GLuint, v: [*c]const GLushort) void = undefined;
    pub var glVertexAttribPointer: fn (index: GLuint, size: GLint, type: GLenum, normalized: GLboolean, stride: GLsizei, pointer: ?*const c_void) void = undefined;
    pub var glUniformMatrix2x3fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix3x2fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix2x4fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix4x2fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix3x4fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glUniformMatrix4x3fv: fn (location: GLint, count: GLsizei, transpose: GLboolean, value: [*c]const GLfloat) void = undefined;
    pub var glIsRenderbuffer: fn (renderbuffer: GLuint) GLboolean = undefined;
    pub var glBindRenderbuffer: fn (target: GLenum, renderbuffer: GLuint) void = undefined;
    pub var glDeleteRenderbuffers: fn (n: GLsizei, renderbuffers: [*c]const GLuint) void = undefined;
    pub var glGenRenderbuffers: fn (n: GLsizei, renderbuffers: [*c]GLuint) void = undefined;
    pub var glRenderbufferStorage: fn (target: GLenum, internalformat: GLenum, width: GLsizei, height: GLsizei) void = undefined;
    pub var glGetRenderbufferParameteriv: fn (target: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glIsFramebuffer: fn (framebuffer: GLuint) GLboolean = undefined;
    pub var glBindFramebuffer: fn (target: GLenum, framebuffer: GLuint) void = undefined;
    pub var glDeleteFramebuffers: fn (n: GLsizei, framebuffers: [*c]const GLuint) void = undefined;
    pub var glGenFramebuffers: fn (n: GLsizei, framebuffers: [*c]GLuint) void = undefined;
    pub var glCheckFramebufferStatus: fn (target: GLenum) GLenum = undefined;
    pub var glFramebufferTexture1D: fn (target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) void = undefined;
    pub var glFramebufferTexture2D: fn (target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) void = undefined;
    pub var glFramebufferTexture3D: fn (target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint, zoffset: GLint) void = undefined;
    pub var glFramebufferRenderbuffer: fn (target: GLenum, attachment: GLenum, renderbuffertarget: GLenum, renderbuffer: GLuint) void = undefined;
    pub var glGetFramebufferAttachmentParameteriv: fn (target: GLenum, attachment: GLenum, pname: GLenum, params: [*c]GLint) void = undefined;
    pub var glGenerateMipmap: fn (target: GLenum) void = undefined;
    pub var glBlitFramebuffer: fn (srcX0: GLint, srcY0: GLint, srcX1: GLint, srcY1: GLint, dstX0: GLint, dstY0: GLint, dstX1: GLint, dstY1: GLint, mask: GLbitfield, filter: GLenum) void = undefined;
    pub var glRenderbufferStorageMultisample: fn (target: GLenum, samples: GLsizei, internalformat: GLenum, width: GLsizei, height: GLsizei) void = undefined;
    pub var glFramebufferTextureLayer: fn (target: GLenum, attachment: GLenum, texture: GLuint, level: GLint, layer: GLint) void = undefined;
};

pub const Command = struct {
    name: [:0]const u8,
    ptr: **const c_void,
};

pub const commands = [_]Command{
    Command{ .name = "glCullFace", .ptr = @ptrCast(**const c_void, &namespace.glCullFace) },
    Command{ .name = "glFrontFace", .ptr = @ptrCast(**const c_void, &namespace.glFrontFace) },
    Command{ .name = "glHint", .ptr = @ptrCast(**const c_void, &namespace.glHint) },
    Command{ .name = "glLineWidth", .ptr = @ptrCast(**const c_void, &namespace.glLineWidth) },
    Command{ .name = "glPointSize", .ptr = @ptrCast(**const c_void, &namespace.glPointSize) },
    Command{ .name = "glPolygonMode", .ptr = @ptrCast(**const c_void, &namespace.glPolygonMode) },
    Command{ .name = "glScissor", .ptr = @ptrCast(**const c_void, &namespace.glScissor) },
    Command{ .name = "glTexParameterf", .ptr = @ptrCast(**const c_void, &namespace.glTexParameterf) },
    Command{ .name = "glTexParameterfv", .ptr = @ptrCast(**const c_void, &namespace.glTexParameterfv) },
    Command{ .name = "glTexParameteri", .ptr = @ptrCast(**const c_void, &namespace.glTexParameteri) },
    Command{ .name = "glTexParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glTexParameteriv) },
    Command{ .name = "glTexImage1D", .ptr = @ptrCast(**const c_void, &namespace.glTexImage1D) },
    Command{ .name = "glTexImage2D", .ptr = @ptrCast(**const c_void, &namespace.glTexImage2D) },
    Command{ .name = "glDrawBuffer", .ptr = @ptrCast(**const c_void, &namespace.glDrawBuffer) },
    Command{ .name = "glClear", .ptr = @ptrCast(**const c_void, &namespace.glClear) },
    Command{ .name = "glClearColor", .ptr = @ptrCast(**const c_void, &namespace.glClearColor) },
    Command{ .name = "glClearStencil", .ptr = @ptrCast(**const c_void, &namespace.glClearStencil) },
    Command{ .name = "glClearDepth", .ptr = @ptrCast(**const c_void, &namespace.glClearDepth) },
    Command{ .name = "glStencilMask", .ptr = @ptrCast(**const c_void, &namespace.glStencilMask) },
    Command{ .name = "glColorMask", .ptr = @ptrCast(**const c_void, &namespace.glColorMask) },
    Command{ .name = "glDepthMask", .ptr = @ptrCast(**const c_void, &namespace.glDepthMask) },
    Command{ .name = "glDisable", .ptr = @ptrCast(**const c_void, &namespace.glDisable) },
    Command{ .name = "glEnable", .ptr = @ptrCast(**const c_void, &namespace.glEnable) },
    Command{ .name = "glFinish", .ptr = @ptrCast(**const c_void, &namespace.glFinish) },
    Command{ .name = "glFlush", .ptr = @ptrCast(**const c_void, &namespace.glFlush) },
    Command{ .name = "glBlendFunc", .ptr = @ptrCast(**const c_void, &namespace.glBlendFunc) },
    Command{ .name = "glLogicOp", .ptr = @ptrCast(**const c_void, &namespace.glLogicOp) },
    Command{ .name = "glStencilFunc", .ptr = @ptrCast(**const c_void, &namespace.glStencilFunc) },
    Command{ .name = "glStencilOp", .ptr = @ptrCast(**const c_void, &namespace.glStencilOp) },
    Command{ .name = "glDepthFunc", .ptr = @ptrCast(**const c_void, &namespace.glDepthFunc) },
    Command{ .name = "glPixelStoref", .ptr = @ptrCast(**const c_void, &namespace.glPixelStoref) },
    Command{ .name = "glPixelStorei", .ptr = @ptrCast(**const c_void, &namespace.glPixelStorei) },
    Command{ .name = "glReadBuffer", .ptr = @ptrCast(**const c_void, &namespace.glReadBuffer) },
    Command{ .name = "glReadPixels", .ptr = @ptrCast(**const c_void, &namespace.glReadPixels) },
    Command{ .name = "glGetBooleanv", .ptr = @ptrCast(**const c_void, &namespace.glGetBooleanv) },
    Command{ .name = "glGetDoublev", .ptr = @ptrCast(**const c_void, &namespace.glGetDoublev) },
    Command{ .name = "glGetError", .ptr = @ptrCast(**const c_void, &namespace.glGetError) },
    Command{ .name = "glGetFloatv", .ptr = @ptrCast(**const c_void, &namespace.glGetFloatv) },
    Command{ .name = "glGetIntegerv", .ptr = @ptrCast(**const c_void, &namespace.glGetIntegerv) },
    Command{ .name = "glGetString", .ptr = @ptrCast(**const c_void, &namespace.glGetString) },
    Command{ .name = "glGetTexImage", .ptr = @ptrCast(**const c_void, &namespace.glGetTexImage) },
    Command{ .name = "glGetTexParameterfv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexParameterfv) },
    Command{ .name = "glGetTexParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexParameteriv) },
    Command{ .name = "glGetTexLevelParameterfv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexLevelParameterfv) },
    Command{ .name = "glGetTexLevelParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexLevelParameteriv) },
    Command{ .name = "glIsEnabled", .ptr = @ptrCast(**const c_void, &namespace.glIsEnabled) },
    Command{ .name = "glDepthRange", .ptr = @ptrCast(**const c_void, &namespace.glDepthRange) },
    Command{ .name = "glViewport", .ptr = @ptrCast(**const c_void, &namespace.glViewport) },
    Command{ .name = "glNewList", .ptr = @ptrCast(**const c_void, &namespace.glNewList) },
    Command{ .name = "glEndList", .ptr = @ptrCast(**const c_void, &namespace.glEndList) },
    Command{ .name = "glCallList", .ptr = @ptrCast(**const c_void, &namespace.glCallList) },
    Command{ .name = "glCallLists", .ptr = @ptrCast(**const c_void, &namespace.glCallLists) },
    Command{ .name = "glDeleteLists", .ptr = @ptrCast(**const c_void, &namespace.glDeleteLists) },
    Command{ .name = "glGenLists", .ptr = @ptrCast(**const c_void, &namespace.glGenLists) },
    Command{ .name = "glListBase", .ptr = @ptrCast(**const c_void, &namespace.glListBase) },
    Command{ .name = "glBegin", .ptr = @ptrCast(**const c_void, &namespace.glBegin) },
    Command{ .name = "glBitmap", .ptr = @ptrCast(**const c_void, &namespace.glBitmap) },
    Command{ .name = "glColor3b", .ptr = @ptrCast(**const c_void, &namespace.glColor3b) },
    Command{ .name = "glColor3bv", .ptr = @ptrCast(**const c_void, &namespace.glColor3bv) },
    Command{ .name = "glColor3d", .ptr = @ptrCast(**const c_void, &namespace.glColor3d) },
    Command{ .name = "glColor3dv", .ptr = @ptrCast(**const c_void, &namespace.glColor3dv) },
    Command{ .name = "glColor3f", .ptr = @ptrCast(**const c_void, &namespace.glColor3f) },
    Command{ .name = "glColor3fv", .ptr = @ptrCast(**const c_void, &namespace.glColor3fv) },
    Command{ .name = "glColor3i", .ptr = @ptrCast(**const c_void, &namespace.glColor3i) },
    Command{ .name = "glColor3iv", .ptr = @ptrCast(**const c_void, &namespace.glColor3iv) },
    Command{ .name = "glColor3s", .ptr = @ptrCast(**const c_void, &namespace.glColor3s) },
    Command{ .name = "glColor3sv", .ptr = @ptrCast(**const c_void, &namespace.glColor3sv) },
    Command{ .name = "glColor3ub", .ptr = @ptrCast(**const c_void, &namespace.glColor3ub) },
    Command{ .name = "glColor3ubv", .ptr = @ptrCast(**const c_void, &namespace.glColor3ubv) },
    Command{ .name = "glColor3ui", .ptr = @ptrCast(**const c_void, &namespace.glColor3ui) },
    Command{ .name = "glColor3uiv", .ptr = @ptrCast(**const c_void, &namespace.glColor3uiv) },
    Command{ .name = "glColor3us", .ptr = @ptrCast(**const c_void, &namespace.glColor3us) },
    Command{ .name = "glColor3usv", .ptr = @ptrCast(**const c_void, &namespace.glColor3usv) },
    Command{ .name = "glColor4b", .ptr = @ptrCast(**const c_void, &namespace.glColor4b) },
    Command{ .name = "glColor4bv", .ptr = @ptrCast(**const c_void, &namespace.glColor4bv) },
    Command{ .name = "glColor4d", .ptr = @ptrCast(**const c_void, &namespace.glColor4d) },
    Command{ .name = "glColor4dv", .ptr = @ptrCast(**const c_void, &namespace.glColor4dv) },
    Command{ .name = "glColor4f", .ptr = @ptrCast(**const c_void, &namespace.glColor4f) },
    Command{ .name = "glColor4fv", .ptr = @ptrCast(**const c_void, &namespace.glColor4fv) },
    Command{ .name = "glColor4i", .ptr = @ptrCast(**const c_void, &namespace.glColor4i) },
    Command{ .name = "glColor4iv", .ptr = @ptrCast(**const c_void, &namespace.glColor4iv) },
    Command{ .name = "glColor4s", .ptr = @ptrCast(**const c_void, &namespace.glColor4s) },
    Command{ .name = "glColor4sv", .ptr = @ptrCast(**const c_void, &namespace.glColor4sv) },
    Command{ .name = "glColor4ub", .ptr = @ptrCast(**const c_void, &namespace.glColor4ub) },
    Command{ .name = "glColor4ubv", .ptr = @ptrCast(**const c_void, &namespace.glColor4ubv) },
    Command{ .name = "glColor4ui", .ptr = @ptrCast(**const c_void, &namespace.glColor4ui) },
    Command{ .name = "glColor4uiv", .ptr = @ptrCast(**const c_void, &namespace.glColor4uiv) },
    Command{ .name = "glColor4us", .ptr = @ptrCast(**const c_void, &namespace.glColor4us) },
    Command{ .name = "glColor4usv", .ptr = @ptrCast(**const c_void, &namespace.glColor4usv) },
    Command{ .name = "glEdgeFlag", .ptr = @ptrCast(**const c_void, &namespace.glEdgeFlag) },
    Command{ .name = "glEdgeFlagv", .ptr = @ptrCast(**const c_void, &namespace.glEdgeFlagv) },
    Command{ .name = "glEnd", .ptr = @ptrCast(**const c_void, &namespace.glEnd) },
    Command{ .name = "glIndexd", .ptr = @ptrCast(**const c_void, &namespace.glIndexd) },
    Command{ .name = "glIndexdv", .ptr = @ptrCast(**const c_void, &namespace.glIndexdv) },
    Command{ .name = "glIndexf", .ptr = @ptrCast(**const c_void, &namespace.glIndexf) },
    Command{ .name = "glIndexfv", .ptr = @ptrCast(**const c_void, &namespace.glIndexfv) },
    Command{ .name = "glIndexi", .ptr = @ptrCast(**const c_void, &namespace.glIndexi) },
    Command{ .name = "glIndexiv", .ptr = @ptrCast(**const c_void, &namespace.glIndexiv) },
    Command{ .name = "glIndexs", .ptr = @ptrCast(**const c_void, &namespace.glIndexs) },
    Command{ .name = "glIndexsv", .ptr = @ptrCast(**const c_void, &namespace.glIndexsv) },
    Command{ .name = "glNormal3b", .ptr = @ptrCast(**const c_void, &namespace.glNormal3b) },
    Command{ .name = "glNormal3bv", .ptr = @ptrCast(**const c_void, &namespace.glNormal3bv) },
    Command{ .name = "glNormal3d", .ptr = @ptrCast(**const c_void, &namespace.glNormal3d) },
    Command{ .name = "glNormal3dv", .ptr = @ptrCast(**const c_void, &namespace.glNormal3dv) },
    Command{ .name = "glNormal3f", .ptr = @ptrCast(**const c_void, &namespace.glNormal3f) },
    Command{ .name = "glNormal3fv", .ptr = @ptrCast(**const c_void, &namespace.glNormal3fv) },
    Command{ .name = "glNormal3i", .ptr = @ptrCast(**const c_void, &namespace.glNormal3i) },
    Command{ .name = "glNormal3iv", .ptr = @ptrCast(**const c_void, &namespace.glNormal3iv) },
    Command{ .name = "glNormal3s", .ptr = @ptrCast(**const c_void, &namespace.glNormal3s) },
    Command{ .name = "glNormal3sv", .ptr = @ptrCast(**const c_void, &namespace.glNormal3sv) },
    Command{ .name = "glRasterPos2d", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2d) },
    Command{ .name = "glRasterPos2dv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2dv) },
    Command{ .name = "glRasterPos2f", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2f) },
    Command{ .name = "glRasterPos2fv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2fv) },
    Command{ .name = "glRasterPos2i", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2i) },
    Command{ .name = "glRasterPos2iv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2iv) },
    Command{ .name = "glRasterPos2s", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2s) },
    Command{ .name = "glRasterPos2sv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos2sv) },
    Command{ .name = "glRasterPos3d", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3d) },
    Command{ .name = "glRasterPos3dv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3dv) },
    Command{ .name = "glRasterPos3f", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3f) },
    Command{ .name = "glRasterPos3fv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3fv) },
    Command{ .name = "glRasterPos3i", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3i) },
    Command{ .name = "glRasterPos3iv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3iv) },
    Command{ .name = "glRasterPos3s", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3s) },
    Command{ .name = "glRasterPos3sv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos3sv) },
    Command{ .name = "glRasterPos4d", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4d) },
    Command{ .name = "glRasterPos4dv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4dv) },
    Command{ .name = "glRasterPos4f", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4f) },
    Command{ .name = "glRasterPos4fv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4fv) },
    Command{ .name = "glRasterPos4i", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4i) },
    Command{ .name = "glRasterPos4iv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4iv) },
    Command{ .name = "glRasterPos4s", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4s) },
    Command{ .name = "glRasterPos4sv", .ptr = @ptrCast(**const c_void, &namespace.glRasterPos4sv) },
    Command{ .name = "glRectd", .ptr = @ptrCast(**const c_void, &namespace.glRectd) },
    Command{ .name = "glRectdv", .ptr = @ptrCast(**const c_void, &namespace.glRectdv) },
    Command{ .name = "glRectf", .ptr = @ptrCast(**const c_void, &namespace.glRectf) },
    Command{ .name = "glRectfv", .ptr = @ptrCast(**const c_void, &namespace.glRectfv) },
    Command{ .name = "glRecti", .ptr = @ptrCast(**const c_void, &namespace.glRecti) },
    Command{ .name = "glRectiv", .ptr = @ptrCast(**const c_void, &namespace.glRectiv) },
    Command{ .name = "glRects", .ptr = @ptrCast(**const c_void, &namespace.glRects) },
    Command{ .name = "glRectsv", .ptr = @ptrCast(**const c_void, &namespace.glRectsv) },
    Command{ .name = "glTexCoord1d", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1d) },
    Command{ .name = "glTexCoord1dv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1dv) },
    Command{ .name = "glTexCoord1f", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1f) },
    Command{ .name = "glTexCoord1fv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1fv) },
    Command{ .name = "glTexCoord1i", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1i) },
    Command{ .name = "glTexCoord1iv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1iv) },
    Command{ .name = "glTexCoord1s", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1s) },
    Command{ .name = "glTexCoord1sv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord1sv) },
    Command{ .name = "glTexCoord2d", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2d) },
    Command{ .name = "glTexCoord2dv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2dv) },
    Command{ .name = "glTexCoord2f", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2f) },
    Command{ .name = "glTexCoord2fv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2fv) },
    Command{ .name = "glTexCoord2i", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2i) },
    Command{ .name = "glTexCoord2iv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2iv) },
    Command{ .name = "glTexCoord2s", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2s) },
    Command{ .name = "glTexCoord2sv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord2sv) },
    Command{ .name = "glTexCoord3d", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3d) },
    Command{ .name = "glTexCoord3dv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3dv) },
    Command{ .name = "glTexCoord3f", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3f) },
    Command{ .name = "glTexCoord3fv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3fv) },
    Command{ .name = "glTexCoord3i", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3i) },
    Command{ .name = "glTexCoord3iv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3iv) },
    Command{ .name = "glTexCoord3s", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3s) },
    Command{ .name = "glTexCoord3sv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord3sv) },
    Command{ .name = "glTexCoord4d", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4d) },
    Command{ .name = "glTexCoord4dv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4dv) },
    Command{ .name = "glTexCoord4f", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4f) },
    Command{ .name = "glTexCoord4fv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4fv) },
    Command{ .name = "glTexCoord4i", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4i) },
    Command{ .name = "glTexCoord4iv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4iv) },
    Command{ .name = "glTexCoord4s", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4s) },
    Command{ .name = "glTexCoord4sv", .ptr = @ptrCast(**const c_void, &namespace.glTexCoord4sv) },
    Command{ .name = "glVertex2d", .ptr = @ptrCast(**const c_void, &namespace.glVertex2d) },
    Command{ .name = "glVertex2dv", .ptr = @ptrCast(**const c_void, &namespace.glVertex2dv) },
    Command{ .name = "glVertex2f", .ptr = @ptrCast(**const c_void, &namespace.glVertex2f) },
    Command{ .name = "glVertex2fv", .ptr = @ptrCast(**const c_void, &namespace.glVertex2fv) },
    Command{ .name = "glVertex2i", .ptr = @ptrCast(**const c_void, &namespace.glVertex2i) },
    Command{ .name = "glVertex2iv", .ptr = @ptrCast(**const c_void, &namespace.glVertex2iv) },
    Command{ .name = "glVertex2s", .ptr = @ptrCast(**const c_void, &namespace.glVertex2s) },
    Command{ .name = "glVertex2sv", .ptr = @ptrCast(**const c_void, &namespace.glVertex2sv) },
    Command{ .name = "glVertex3d", .ptr = @ptrCast(**const c_void, &namespace.glVertex3d) },
    Command{ .name = "glVertex3dv", .ptr = @ptrCast(**const c_void, &namespace.glVertex3dv) },
    Command{ .name = "glVertex3f", .ptr = @ptrCast(**const c_void, &namespace.glVertex3f) },
    Command{ .name = "glVertex3fv", .ptr = @ptrCast(**const c_void, &namespace.glVertex3fv) },
    Command{ .name = "glVertex3i", .ptr = @ptrCast(**const c_void, &namespace.glVertex3i) },
    Command{ .name = "glVertex3iv", .ptr = @ptrCast(**const c_void, &namespace.glVertex3iv) },
    Command{ .name = "glVertex3s", .ptr = @ptrCast(**const c_void, &namespace.glVertex3s) },
    Command{ .name = "glVertex3sv", .ptr = @ptrCast(**const c_void, &namespace.glVertex3sv) },
    Command{ .name = "glVertex4d", .ptr = @ptrCast(**const c_void, &namespace.glVertex4d) },
    Command{ .name = "glVertex4dv", .ptr = @ptrCast(**const c_void, &namespace.glVertex4dv) },
    Command{ .name = "glVertex4f", .ptr = @ptrCast(**const c_void, &namespace.glVertex4f) },
    Command{ .name = "glVertex4fv", .ptr = @ptrCast(**const c_void, &namespace.glVertex4fv) },
    Command{ .name = "glVertex4i", .ptr = @ptrCast(**const c_void, &namespace.glVertex4i) },
    Command{ .name = "glVertex4iv", .ptr = @ptrCast(**const c_void, &namespace.glVertex4iv) },
    Command{ .name = "glVertex4s", .ptr = @ptrCast(**const c_void, &namespace.glVertex4s) },
    Command{ .name = "glVertex4sv", .ptr = @ptrCast(**const c_void, &namespace.glVertex4sv) },
    Command{ .name = "glClipPlane", .ptr = @ptrCast(**const c_void, &namespace.glClipPlane) },
    Command{ .name = "glColorMaterial", .ptr = @ptrCast(**const c_void, &namespace.glColorMaterial) },
    Command{ .name = "glFogf", .ptr = @ptrCast(**const c_void, &namespace.glFogf) },
    Command{ .name = "glFogfv", .ptr = @ptrCast(**const c_void, &namespace.glFogfv) },
    Command{ .name = "glFogi", .ptr = @ptrCast(**const c_void, &namespace.glFogi) },
    Command{ .name = "glFogiv", .ptr = @ptrCast(**const c_void, &namespace.glFogiv) },
    Command{ .name = "glLightf", .ptr = @ptrCast(**const c_void, &namespace.glLightf) },
    Command{ .name = "glLightfv", .ptr = @ptrCast(**const c_void, &namespace.glLightfv) },
    Command{ .name = "glLighti", .ptr = @ptrCast(**const c_void, &namespace.glLighti) },
    Command{ .name = "glLightiv", .ptr = @ptrCast(**const c_void, &namespace.glLightiv) },
    Command{ .name = "glLightModelf", .ptr = @ptrCast(**const c_void, &namespace.glLightModelf) },
    Command{ .name = "glLightModelfv", .ptr = @ptrCast(**const c_void, &namespace.glLightModelfv) },
    Command{ .name = "glLightModeli", .ptr = @ptrCast(**const c_void, &namespace.glLightModeli) },
    Command{ .name = "glLightModeliv", .ptr = @ptrCast(**const c_void, &namespace.glLightModeliv) },
    Command{ .name = "glLineStipple", .ptr = @ptrCast(**const c_void, &namespace.glLineStipple) },
    Command{ .name = "glMaterialf", .ptr = @ptrCast(**const c_void, &namespace.glMaterialf) },
    Command{ .name = "glMaterialfv", .ptr = @ptrCast(**const c_void, &namespace.glMaterialfv) },
    Command{ .name = "glMateriali", .ptr = @ptrCast(**const c_void, &namespace.glMateriali) },
    Command{ .name = "glMaterialiv", .ptr = @ptrCast(**const c_void, &namespace.glMaterialiv) },
    Command{ .name = "glPolygonStipple", .ptr = @ptrCast(**const c_void, &namespace.glPolygonStipple) },
    Command{ .name = "glShadeModel", .ptr = @ptrCast(**const c_void, &namespace.glShadeModel) },
    Command{ .name = "glTexEnvf", .ptr = @ptrCast(**const c_void, &namespace.glTexEnvf) },
    Command{ .name = "glTexEnvfv", .ptr = @ptrCast(**const c_void, &namespace.glTexEnvfv) },
    Command{ .name = "glTexEnvi", .ptr = @ptrCast(**const c_void, &namespace.glTexEnvi) },
    Command{ .name = "glTexEnviv", .ptr = @ptrCast(**const c_void, &namespace.glTexEnviv) },
    Command{ .name = "glTexGend", .ptr = @ptrCast(**const c_void, &namespace.glTexGend) },
    Command{ .name = "glTexGendv", .ptr = @ptrCast(**const c_void, &namespace.glTexGendv) },
    Command{ .name = "glTexGenf", .ptr = @ptrCast(**const c_void, &namespace.glTexGenf) },
    Command{ .name = "glTexGenfv", .ptr = @ptrCast(**const c_void, &namespace.glTexGenfv) },
    Command{ .name = "glTexGeni", .ptr = @ptrCast(**const c_void, &namespace.glTexGeni) },
    Command{ .name = "glTexGeniv", .ptr = @ptrCast(**const c_void, &namespace.glTexGeniv) },
    Command{ .name = "glFeedbackBuffer", .ptr = @ptrCast(**const c_void, &namespace.glFeedbackBuffer) },
    Command{ .name = "glSelectBuffer", .ptr = @ptrCast(**const c_void, &namespace.glSelectBuffer) },
    Command{ .name = "glRenderMode", .ptr = @ptrCast(**const c_void, &namespace.glRenderMode) },
    Command{ .name = "glInitNames", .ptr = @ptrCast(**const c_void, &namespace.glInitNames) },
    Command{ .name = "glLoadName", .ptr = @ptrCast(**const c_void, &namespace.glLoadName) },
    Command{ .name = "glPassThrough", .ptr = @ptrCast(**const c_void, &namespace.glPassThrough) },
    Command{ .name = "glPopName", .ptr = @ptrCast(**const c_void, &namespace.glPopName) },
    Command{ .name = "glPushName", .ptr = @ptrCast(**const c_void, &namespace.glPushName) },
    Command{ .name = "glClearAccum", .ptr = @ptrCast(**const c_void, &namespace.glClearAccum) },
    Command{ .name = "glClearIndex", .ptr = @ptrCast(**const c_void, &namespace.glClearIndex) },
    Command{ .name = "glIndexMask", .ptr = @ptrCast(**const c_void, &namespace.glIndexMask) },
    Command{ .name = "glAccum", .ptr = @ptrCast(**const c_void, &namespace.glAccum) },
    Command{ .name = "glPopAttrib", .ptr = @ptrCast(**const c_void, &namespace.glPopAttrib) },
    Command{ .name = "glPushAttrib", .ptr = @ptrCast(**const c_void, &namespace.glPushAttrib) },
    Command{ .name = "glMap1d", .ptr = @ptrCast(**const c_void, &namespace.glMap1d) },
    Command{ .name = "glMap1f", .ptr = @ptrCast(**const c_void, &namespace.glMap1f) },
    Command{ .name = "glMap2d", .ptr = @ptrCast(**const c_void, &namespace.glMap2d) },
    Command{ .name = "glMap2f", .ptr = @ptrCast(**const c_void, &namespace.glMap2f) },
    Command{ .name = "glMapGrid1d", .ptr = @ptrCast(**const c_void, &namespace.glMapGrid1d) },
    Command{ .name = "glMapGrid1f", .ptr = @ptrCast(**const c_void, &namespace.glMapGrid1f) },
    Command{ .name = "glMapGrid2d", .ptr = @ptrCast(**const c_void, &namespace.glMapGrid2d) },
    Command{ .name = "glMapGrid2f", .ptr = @ptrCast(**const c_void, &namespace.glMapGrid2f) },
    Command{ .name = "glEvalCoord1d", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord1d) },
    Command{ .name = "glEvalCoord1dv", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord1dv) },
    Command{ .name = "glEvalCoord1f", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord1f) },
    Command{ .name = "glEvalCoord1fv", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord1fv) },
    Command{ .name = "glEvalCoord2d", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord2d) },
    Command{ .name = "glEvalCoord2dv", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord2dv) },
    Command{ .name = "glEvalCoord2f", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord2f) },
    Command{ .name = "glEvalCoord2fv", .ptr = @ptrCast(**const c_void, &namespace.glEvalCoord2fv) },
    Command{ .name = "glEvalMesh1", .ptr = @ptrCast(**const c_void, &namespace.glEvalMesh1) },
    Command{ .name = "glEvalPoint1", .ptr = @ptrCast(**const c_void, &namespace.glEvalPoint1) },
    Command{ .name = "glEvalMesh2", .ptr = @ptrCast(**const c_void, &namespace.glEvalMesh2) },
    Command{ .name = "glEvalPoint2", .ptr = @ptrCast(**const c_void, &namespace.glEvalPoint2) },
    Command{ .name = "glAlphaFunc", .ptr = @ptrCast(**const c_void, &namespace.glAlphaFunc) },
    Command{ .name = "glPixelZoom", .ptr = @ptrCast(**const c_void, &namespace.glPixelZoom) },
    Command{ .name = "glPixelTransferf", .ptr = @ptrCast(**const c_void, &namespace.glPixelTransferf) },
    Command{ .name = "glPixelTransferi", .ptr = @ptrCast(**const c_void, &namespace.glPixelTransferi) },
    Command{ .name = "glPixelMapfv", .ptr = @ptrCast(**const c_void, &namespace.glPixelMapfv) },
    Command{ .name = "glPixelMapuiv", .ptr = @ptrCast(**const c_void, &namespace.glPixelMapuiv) },
    Command{ .name = "glPixelMapusv", .ptr = @ptrCast(**const c_void, &namespace.glPixelMapusv) },
    Command{ .name = "glCopyPixels", .ptr = @ptrCast(**const c_void, &namespace.glCopyPixels) },
    Command{ .name = "glDrawPixels", .ptr = @ptrCast(**const c_void, &namespace.glDrawPixels) },
    Command{ .name = "glGetClipPlane", .ptr = @ptrCast(**const c_void, &namespace.glGetClipPlane) },
    Command{ .name = "glGetLightfv", .ptr = @ptrCast(**const c_void, &namespace.glGetLightfv) },
    Command{ .name = "glGetLightiv", .ptr = @ptrCast(**const c_void, &namespace.glGetLightiv) },
    Command{ .name = "glGetMapdv", .ptr = @ptrCast(**const c_void, &namespace.glGetMapdv) },
    Command{ .name = "glGetMapfv", .ptr = @ptrCast(**const c_void, &namespace.glGetMapfv) },
    Command{ .name = "glGetMapiv", .ptr = @ptrCast(**const c_void, &namespace.glGetMapiv) },
    Command{ .name = "glGetMaterialfv", .ptr = @ptrCast(**const c_void, &namespace.glGetMaterialfv) },
    Command{ .name = "glGetMaterialiv", .ptr = @ptrCast(**const c_void, &namespace.glGetMaterialiv) },
    Command{ .name = "glGetPixelMapfv", .ptr = @ptrCast(**const c_void, &namespace.glGetPixelMapfv) },
    Command{ .name = "glGetPixelMapuiv", .ptr = @ptrCast(**const c_void, &namespace.glGetPixelMapuiv) },
    Command{ .name = "glGetPixelMapusv", .ptr = @ptrCast(**const c_void, &namespace.glGetPixelMapusv) },
    Command{ .name = "glGetPolygonStipple", .ptr = @ptrCast(**const c_void, &namespace.glGetPolygonStipple) },
    Command{ .name = "glGetTexEnvfv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexEnvfv) },
    Command{ .name = "glGetTexEnviv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexEnviv) },
    Command{ .name = "glGetTexGendv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexGendv) },
    Command{ .name = "glGetTexGenfv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexGenfv) },
    Command{ .name = "glGetTexGeniv", .ptr = @ptrCast(**const c_void, &namespace.glGetTexGeniv) },
    Command{ .name = "glIsList", .ptr = @ptrCast(**const c_void, &namespace.glIsList) },
    Command{ .name = "glFrustum", .ptr = @ptrCast(**const c_void, &namespace.glFrustum) },
    Command{ .name = "glLoadIdentity", .ptr = @ptrCast(**const c_void, &namespace.glLoadIdentity) },
    Command{ .name = "glLoadMatrixf", .ptr = @ptrCast(**const c_void, &namespace.glLoadMatrixf) },
    Command{ .name = "glLoadMatrixd", .ptr = @ptrCast(**const c_void, &namespace.glLoadMatrixd) },
    Command{ .name = "glMatrixMode", .ptr = @ptrCast(**const c_void, &namespace.glMatrixMode) },
    Command{ .name = "glMultMatrixf", .ptr = @ptrCast(**const c_void, &namespace.glMultMatrixf) },
    Command{ .name = "glMultMatrixd", .ptr = @ptrCast(**const c_void, &namespace.glMultMatrixd) },
    Command{ .name = "glOrtho", .ptr = @ptrCast(**const c_void, &namespace.glOrtho) },
    Command{ .name = "glPopMatrix", .ptr = @ptrCast(**const c_void, &namespace.glPopMatrix) },
    Command{ .name = "glPushMatrix", .ptr = @ptrCast(**const c_void, &namespace.glPushMatrix) },
    Command{ .name = "glRotated", .ptr = @ptrCast(**const c_void, &namespace.glRotated) },
    Command{ .name = "glRotatef", .ptr = @ptrCast(**const c_void, &namespace.glRotatef) },
    Command{ .name = "glScaled", .ptr = @ptrCast(**const c_void, &namespace.glScaled) },
    Command{ .name = "glScalef", .ptr = @ptrCast(**const c_void, &namespace.glScalef) },
    Command{ .name = "glTranslated", .ptr = @ptrCast(**const c_void, &namespace.glTranslated) },
    Command{ .name = "glTranslatef", .ptr = @ptrCast(**const c_void, &namespace.glTranslatef) },
    Command{ .name = "glDrawArrays", .ptr = @ptrCast(**const c_void, &namespace.glDrawArrays) },
    Command{ .name = "glDrawElements", .ptr = @ptrCast(**const c_void, &namespace.glDrawElements) },
    Command{ .name = "glGetPointerv", .ptr = @ptrCast(**const c_void, &namespace.glGetPointerv) },
    Command{ .name = "glPolygonOffset", .ptr = @ptrCast(**const c_void, &namespace.glPolygonOffset) },
    Command{ .name = "glCopyTexImage1D", .ptr = @ptrCast(**const c_void, &namespace.glCopyTexImage1D) },
    Command{ .name = "glCopyTexImage2D", .ptr = @ptrCast(**const c_void, &namespace.glCopyTexImage2D) },
    Command{ .name = "glCopyTexSubImage1D", .ptr = @ptrCast(**const c_void, &namespace.glCopyTexSubImage1D) },
    Command{ .name = "glCopyTexSubImage2D", .ptr = @ptrCast(**const c_void, &namespace.glCopyTexSubImage2D) },
    Command{ .name = "glTexSubImage1D", .ptr = @ptrCast(**const c_void, &namespace.glTexSubImage1D) },
    Command{ .name = "glTexSubImage2D", .ptr = @ptrCast(**const c_void, &namespace.glTexSubImage2D) },
    Command{ .name = "glBindTexture", .ptr = @ptrCast(**const c_void, &namespace.glBindTexture) },
    Command{ .name = "glDeleteTextures", .ptr = @ptrCast(**const c_void, &namespace.glDeleteTextures) },
    Command{ .name = "glGenTextures", .ptr = @ptrCast(**const c_void, &namespace.glGenTextures) },
    Command{ .name = "glIsTexture", .ptr = @ptrCast(**const c_void, &namespace.glIsTexture) },
    Command{ .name = "glArrayElement", .ptr = @ptrCast(**const c_void, &namespace.glArrayElement) },
    Command{ .name = "glColorPointer", .ptr = @ptrCast(**const c_void, &namespace.glColorPointer) },
    Command{ .name = "glDisableClientState", .ptr = @ptrCast(**const c_void, &namespace.glDisableClientState) },
    Command{ .name = "glEdgeFlagPointer", .ptr = @ptrCast(**const c_void, &namespace.glEdgeFlagPointer) },
    Command{ .name = "glEnableClientState", .ptr = @ptrCast(**const c_void, &namespace.glEnableClientState) },
    Command{ .name = "glIndexPointer", .ptr = @ptrCast(**const c_void, &namespace.glIndexPointer) },
    Command{ .name = "glInterleavedArrays", .ptr = @ptrCast(**const c_void, &namespace.glInterleavedArrays) },
    Command{ .name = "glNormalPointer", .ptr = @ptrCast(**const c_void, &namespace.glNormalPointer) },
    Command{ .name = "glTexCoordPointer", .ptr = @ptrCast(**const c_void, &namespace.glTexCoordPointer) },
    Command{ .name = "glVertexPointer", .ptr = @ptrCast(**const c_void, &namespace.glVertexPointer) },
    Command{ .name = "glAreTexturesResident", .ptr = @ptrCast(**const c_void, &namespace.glAreTexturesResident) },
    Command{ .name = "glPrioritizeTextures", .ptr = @ptrCast(**const c_void, &namespace.glPrioritizeTextures) },
    Command{ .name = "glIndexub", .ptr = @ptrCast(**const c_void, &namespace.glIndexub) },
    Command{ .name = "glIndexubv", .ptr = @ptrCast(**const c_void, &namespace.glIndexubv) },
    Command{ .name = "glPopClientAttrib", .ptr = @ptrCast(**const c_void, &namespace.glPopClientAttrib) },
    Command{ .name = "glPushClientAttrib", .ptr = @ptrCast(**const c_void, &namespace.glPushClientAttrib) },
    Command{ .name = "glDrawRangeElements", .ptr = @ptrCast(**const c_void, &namespace.glDrawRangeElements) },
    Command{ .name = "glTexImage3D", .ptr = @ptrCast(**const c_void, &namespace.glTexImage3D) },
    Command{ .name = "glTexSubImage3D", .ptr = @ptrCast(**const c_void, &namespace.glTexSubImage3D) },
    Command{ .name = "glCopyTexSubImage3D", .ptr = @ptrCast(**const c_void, &namespace.glCopyTexSubImage3D) },
    Command{ .name = "glActiveTexture", .ptr = @ptrCast(**const c_void, &namespace.glActiveTexture) },
    Command{ .name = "glSampleCoverage", .ptr = @ptrCast(**const c_void, &namespace.glSampleCoverage) },
    Command{ .name = "glCompressedTexImage3D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexImage3D) },
    Command{ .name = "glCompressedTexImage2D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexImage2D) },
    Command{ .name = "glCompressedTexImage1D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexImage1D) },
    Command{ .name = "glCompressedTexSubImage3D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexSubImage3D) },
    Command{ .name = "glCompressedTexSubImage2D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexSubImage2D) },
    Command{ .name = "glCompressedTexSubImage1D", .ptr = @ptrCast(**const c_void, &namespace.glCompressedTexSubImage1D) },
    Command{ .name = "glGetCompressedTexImage", .ptr = @ptrCast(**const c_void, &namespace.glGetCompressedTexImage) },
    Command{ .name = "glClientActiveTexture", .ptr = @ptrCast(**const c_void, &namespace.glClientActiveTexture) },
    Command{ .name = "glMultiTexCoord1d", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1d) },
    Command{ .name = "glMultiTexCoord1dv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1dv) },
    Command{ .name = "glMultiTexCoord1f", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1f) },
    Command{ .name = "glMultiTexCoord1fv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1fv) },
    Command{ .name = "glMultiTexCoord1i", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1i) },
    Command{ .name = "glMultiTexCoord1iv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1iv) },
    Command{ .name = "glMultiTexCoord1s", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1s) },
    Command{ .name = "glMultiTexCoord1sv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord1sv) },
    Command{ .name = "glMultiTexCoord2d", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2d) },
    Command{ .name = "glMultiTexCoord2dv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2dv) },
    Command{ .name = "glMultiTexCoord2f", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2f) },
    Command{ .name = "glMultiTexCoord2fv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2fv) },
    Command{ .name = "glMultiTexCoord2i", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2i) },
    Command{ .name = "glMultiTexCoord2iv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2iv) },
    Command{ .name = "glMultiTexCoord2s", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2s) },
    Command{ .name = "glMultiTexCoord2sv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord2sv) },
    Command{ .name = "glMultiTexCoord3d", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3d) },
    Command{ .name = "glMultiTexCoord3dv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3dv) },
    Command{ .name = "glMultiTexCoord3f", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3f) },
    Command{ .name = "glMultiTexCoord3fv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3fv) },
    Command{ .name = "glMultiTexCoord3i", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3i) },
    Command{ .name = "glMultiTexCoord3iv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3iv) },
    Command{ .name = "glMultiTexCoord3s", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3s) },
    Command{ .name = "glMultiTexCoord3sv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord3sv) },
    Command{ .name = "glMultiTexCoord4d", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4d) },
    Command{ .name = "glMultiTexCoord4dv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4dv) },
    Command{ .name = "glMultiTexCoord4f", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4f) },
    Command{ .name = "glMultiTexCoord4fv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4fv) },
    Command{ .name = "glMultiTexCoord4i", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4i) },
    Command{ .name = "glMultiTexCoord4iv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4iv) },
    Command{ .name = "glMultiTexCoord4s", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4s) },
    Command{ .name = "glMultiTexCoord4sv", .ptr = @ptrCast(**const c_void, &namespace.glMultiTexCoord4sv) },
    Command{ .name = "glLoadTransposeMatrixf", .ptr = @ptrCast(**const c_void, &namespace.glLoadTransposeMatrixf) },
    Command{ .name = "glLoadTransposeMatrixd", .ptr = @ptrCast(**const c_void, &namespace.glLoadTransposeMatrixd) },
    Command{ .name = "glMultTransposeMatrixf", .ptr = @ptrCast(**const c_void, &namespace.glMultTransposeMatrixf) },
    Command{ .name = "glMultTransposeMatrixd", .ptr = @ptrCast(**const c_void, &namespace.glMultTransposeMatrixd) },
    Command{ .name = "glBlendFuncSeparate", .ptr = @ptrCast(**const c_void, &namespace.glBlendFuncSeparate) },
    Command{ .name = "glMultiDrawArrays", .ptr = @ptrCast(**const c_void, &namespace.glMultiDrawArrays) },
    Command{ .name = "glMultiDrawElements", .ptr = @ptrCast(**const c_void, &namespace.glMultiDrawElements) },
    Command{ .name = "glPointParameterf", .ptr = @ptrCast(**const c_void, &namespace.glPointParameterf) },
    Command{ .name = "glPointParameterfv", .ptr = @ptrCast(**const c_void, &namespace.glPointParameterfv) },
    Command{ .name = "glPointParameteri", .ptr = @ptrCast(**const c_void, &namespace.glPointParameteri) },
    Command{ .name = "glPointParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glPointParameteriv) },
    Command{ .name = "glFogCoordf", .ptr = @ptrCast(**const c_void, &namespace.glFogCoordf) },
    Command{ .name = "glFogCoordfv", .ptr = @ptrCast(**const c_void, &namespace.glFogCoordfv) },
    Command{ .name = "glFogCoordd", .ptr = @ptrCast(**const c_void, &namespace.glFogCoordd) },
    Command{ .name = "glFogCoorddv", .ptr = @ptrCast(**const c_void, &namespace.glFogCoorddv) },
    Command{ .name = "glFogCoordPointer", .ptr = @ptrCast(**const c_void, &namespace.glFogCoordPointer) },
    Command{ .name = "glSecondaryColor3b", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3b) },
    Command{ .name = "glSecondaryColor3bv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3bv) },
    Command{ .name = "glSecondaryColor3d", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3d) },
    Command{ .name = "glSecondaryColor3dv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3dv) },
    Command{ .name = "glSecondaryColor3f", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3f) },
    Command{ .name = "glSecondaryColor3fv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3fv) },
    Command{ .name = "glSecondaryColor3i", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3i) },
    Command{ .name = "glSecondaryColor3iv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3iv) },
    Command{ .name = "glSecondaryColor3s", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3s) },
    Command{ .name = "glSecondaryColor3sv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3sv) },
    Command{ .name = "glSecondaryColor3ub", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3ub) },
    Command{ .name = "glSecondaryColor3ubv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3ubv) },
    Command{ .name = "glSecondaryColor3ui", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3ui) },
    Command{ .name = "glSecondaryColor3uiv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3uiv) },
    Command{ .name = "glSecondaryColor3us", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3us) },
    Command{ .name = "glSecondaryColor3usv", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColor3usv) },
    Command{ .name = "glSecondaryColorPointer", .ptr = @ptrCast(**const c_void, &namespace.glSecondaryColorPointer) },
    Command{ .name = "glWindowPos2d", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2d) },
    Command{ .name = "glWindowPos2dv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2dv) },
    Command{ .name = "glWindowPos2f", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2f) },
    Command{ .name = "glWindowPos2fv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2fv) },
    Command{ .name = "glWindowPos2i", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2i) },
    Command{ .name = "glWindowPos2iv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2iv) },
    Command{ .name = "glWindowPos2s", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2s) },
    Command{ .name = "glWindowPos2sv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos2sv) },
    Command{ .name = "glWindowPos3d", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3d) },
    Command{ .name = "glWindowPos3dv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3dv) },
    Command{ .name = "glWindowPos3f", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3f) },
    Command{ .name = "glWindowPos3fv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3fv) },
    Command{ .name = "glWindowPos3i", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3i) },
    Command{ .name = "glWindowPos3iv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3iv) },
    Command{ .name = "glWindowPos3s", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3s) },
    Command{ .name = "glWindowPos3sv", .ptr = @ptrCast(**const c_void, &namespace.glWindowPos3sv) },
    Command{ .name = "glBlendColor", .ptr = @ptrCast(**const c_void, &namespace.glBlendColor) },
    Command{ .name = "glBlendEquation", .ptr = @ptrCast(**const c_void, &namespace.glBlendEquation) },
    Command{ .name = "glGenQueries", .ptr = @ptrCast(**const c_void, &namespace.glGenQueries) },
    Command{ .name = "glDeleteQueries", .ptr = @ptrCast(**const c_void, &namespace.glDeleteQueries) },
    Command{ .name = "glIsQuery", .ptr = @ptrCast(**const c_void, &namespace.glIsQuery) },
    Command{ .name = "glBeginQuery", .ptr = @ptrCast(**const c_void, &namespace.glBeginQuery) },
    Command{ .name = "glEndQuery", .ptr = @ptrCast(**const c_void, &namespace.glEndQuery) },
    Command{ .name = "glGetQueryiv", .ptr = @ptrCast(**const c_void, &namespace.glGetQueryiv) },
    Command{ .name = "glGetQueryObjectiv", .ptr = @ptrCast(**const c_void, &namespace.glGetQueryObjectiv) },
    Command{ .name = "glGetQueryObjectuiv", .ptr = @ptrCast(**const c_void, &namespace.glGetQueryObjectuiv) },
    Command{ .name = "glBindBuffer", .ptr = @ptrCast(**const c_void, &namespace.glBindBuffer) },
    Command{ .name = "glDeleteBuffers", .ptr = @ptrCast(**const c_void, &namespace.glDeleteBuffers) },
    Command{ .name = "glGenBuffers", .ptr = @ptrCast(**const c_void, &namespace.glGenBuffers) },
    Command{ .name = "glIsBuffer", .ptr = @ptrCast(**const c_void, &namespace.glIsBuffer) },
    Command{ .name = "glBufferData", .ptr = @ptrCast(**const c_void, &namespace.glBufferData) },
    Command{ .name = "glBufferSubData", .ptr = @ptrCast(**const c_void, &namespace.glBufferSubData) },
    Command{ .name = "glGetBufferSubData", .ptr = @ptrCast(**const c_void, &namespace.glGetBufferSubData) },
    Command{ .name = "glMapBuffer", .ptr = @ptrCast(**const c_void, &namespace.glMapBuffer) },
    Command{ .name = "glUnmapBuffer", .ptr = @ptrCast(**const c_void, &namespace.glUnmapBuffer) },
    Command{ .name = "glGetBufferParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glGetBufferParameteriv) },
    Command{ .name = "glGetBufferPointerv", .ptr = @ptrCast(**const c_void, &namespace.glGetBufferPointerv) },
    Command{ .name = "glBlendEquationSeparate", .ptr = @ptrCast(**const c_void, &namespace.glBlendEquationSeparate) },
    Command{ .name = "glDrawBuffers", .ptr = @ptrCast(**const c_void, &namespace.glDrawBuffers) },
    Command{ .name = "glStencilOpSeparate", .ptr = @ptrCast(**const c_void, &namespace.glStencilOpSeparate) },
    Command{ .name = "glStencilFuncSeparate", .ptr = @ptrCast(**const c_void, &namespace.glStencilFuncSeparate) },
    Command{ .name = "glStencilMaskSeparate", .ptr = @ptrCast(**const c_void, &namespace.glStencilMaskSeparate) },
    Command{ .name = "glAttachShader", .ptr = @ptrCast(**const c_void, &namespace.glAttachShader) },
    Command{ .name = "glBindAttribLocation", .ptr = @ptrCast(**const c_void, &namespace.glBindAttribLocation) },
    Command{ .name = "glCompileShader", .ptr = @ptrCast(**const c_void, &namespace.glCompileShader) },
    Command{ .name = "glCreateProgram", .ptr = @ptrCast(**const c_void, &namespace.glCreateProgram) },
    Command{ .name = "glCreateShader", .ptr = @ptrCast(**const c_void, &namespace.glCreateShader) },
    Command{ .name = "glDeleteProgram", .ptr = @ptrCast(**const c_void, &namespace.glDeleteProgram) },
    Command{ .name = "glDeleteShader", .ptr = @ptrCast(**const c_void, &namespace.glDeleteShader) },
    Command{ .name = "glDetachShader", .ptr = @ptrCast(**const c_void, &namespace.glDetachShader) },
    Command{ .name = "glDisableVertexAttribArray", .ptr = @ptrCast(**const c_void, &namespace.glDisableVertexAttribArray) },
    Command{ .name = "glEnableVertexAttribArray", .ptr = @ptrCast(**const c_void, &namespace.glEnableVertexAttribArray) },
    Command{ .name = "glGetActiveAttrib", .ptr = @ptrCast(**const c_void, &namespace.glGetActiveAttrib) },
    Command{ .name = "glGetActiveUniform", .ptr = @ptrCast(**const c_void, &namespace.glGetActiveUniform) },
    Command{ .name = "glGetAttachedShaders", .ptr = @ptrCast(**const c_void, &namespace.glGetAttachedShaders) },
    Command{ .name = "glGetAttribLocation", .ptr = @ptrCast(**const c_void, &namespace.glGetAttribLocation) },
    Command{ .name = "glGetProgramiv", .ptr = @ptrCast(**const c_void, &namespace.glGetProgramiv) },
    Command{ .name = "glGetProgramInfoLog", .ptr = @ptrCast(**const c_void, &namespace.glGetProgramInfoLog) },
    Command{ .name = "glGetShaderiv", .ptr = @ptrCast(**const c_void, &namespace.glGetShaderiv) },
    Command{ .name = "glGetShaderInfoLog", .ptr = @ptrCast(**const c_void, &namespace.glGetShaderInfoLog) },
    Command{ .name = "glGetShaderSource", .ptr = @ptrCast(**const c_void, &namespace.glGetShaderSource) },
    Command{ .name = "glGetUniformLocation", .ptr = @ptrCast(**const c_void, &namespace.glGetUniformLocation) },
    Command{ .name = "glGetUniformfv", .ptr = @ptrCast(**const c_void, &namespace.glGetUniformfv) },
    Command{ .name = "glGetUniformiv", .ptr = @ptrCast(**const c_void, &namespace.glGetUniformiv) },
    Command{ .name = "glGetVertexAttribdv", .ptr = @ptrCast(**const c_void, &namespace.glGetVertexAttribdv) },
    Command{ .name = "glGetVertexAttribfv", .ptr = @ptrCast(**const c_void, &namespace.glGetVertexAttribfv) },
    Command{ .name = "glGetVertexAttribiv", .ptr = @ptrCast(**const c_void, &namespace.glGetVertexAttribiv) },
    Command{ .name = "glGetVertexAttribPointerv", .ptr = @ptrCast(**const c_void, &namespace.glGetVertexAttribPointerv) },
    Command{ .name = "glIsProgram", .ptr = @ptrCast(**const c_void, &namespace.glIsProgram) },
    Command{ .name = "glIsShader", .ptr = @ptrCast(**const c_void, &namespace.glIsShader) },
    Command{ .name = "glLinkProgram", .ptr = @ptrCast(**const c_void, &namespace.glLinkProgram) },
    Command{ .name = "glShaderSource", .ptr = @ptrCast(**const c_void, &namespace.glShaderSource) },
    Command{ .name = "glUseProgram", .ptr = @ptrCast(**const c_void, &namespace.glUseProgram) },
    Command{ .name = "glUniform1f", .ptr = @ptrCast(**const c_void, &namespace.glUniform1f) },
    Command{ .name = "glUniform2f", .ptr = @ptrCast(**const c_void, &namespace.glUniform2f) },
    Command{ .name = "glUniform3f", .ptr = @ptrCast(**const c_void, &namespace.glUniform3f) },
    Command{ .name = "glUniform4f", .ptr = @ptrCast(**const c_void, &namespace.glUniform4f) },
    Command{ .name = "glUniform1i", .ptr = @ptrCast(**const c_void, &namespace.glUniform1i) },
    Command{ .name = "glUniform2i", .ptr = @ptrCast(**const c_void, &namespace.glUniform2i) },
    Command{ .name = "glUniform3i", .ptr = @ptrCast(**const c_void, &namespace.glUniform3i) },
    Command{ .name = "glUniform4i", .ptr = @ptrCast(**const c_void, &namespace.glUniform4i) },
    Command{ .name = "glUniform1fv", .ptr = @ptrCast(**const c_void, &namespace.glUniform1fv) },
    Command{ .name = "glUniform2fv", .ptr = @ptrCast(**const c_void, &namespace.glUniform2fv) },
    Command{ .name = "glUniform3fv", .ptr = @ptrCast(**const c_void, &namespace.glUniform3fv) },
    Command{ .name = "glUniform4fv", .ptr = @ptrCast(**const c_void, &namespace.glUniform4fv) },
    Command{ .name = "glUniform1iv", .ptr = @ptrCast(**const c_void, &namespace.glUniform1iv) },
    Command{ .name = "glUniform2iv", .ptr = @ptrCast(**const c_void, &namespace.glUniform2iv) },
    Command{ .name = "glUniform3iv", .ptr = @ptrCast(**const c_void, &namespace.glUniform3iv) },
    Command{ .name = "glUniform4iv", .ptr = @ptrCast(**const c_void, &namespace.glUniform4iv) },
    Command{ .name = "glUniformMatrix2fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix2fv) },
    Command{ .name = "glUniformMatrix3fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix3fv) },
    Command{ .name = "glUniformMatrix4fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix4fv) },
    Command{ .name = "glValidateProgram", .ptr = @ptrCast(**const c_void, &namespace.glValidateProgram) },
    Command{ .name = "glVertexAttrib1d", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1d) },
    Command{ .name = "glVertexAttrib1dv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1dv) },
    Command{ .name = "glVertexAttrib1f", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1f) },
    Command{ .name = "glVertexAttrib1fv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1fv) },
    Command{ .name = "glVertexAttrib1s", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1s) },
    Command{ .name = "glVertexAttrib1sv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib1sv) },
    Command{ .name = "glVertexAttrib2d", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2d) },
    Command{ .name = "glVertexAttrib2dv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2dv) },
    Command{ .name = "glVertexAttrib2f", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2f) },
    Command{ .name = "glVertexAttrib2fv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2fv) },
    Command{ .name = "glVertexAttrib2s", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2s) },
    Command{ .name = "glVertexAttrib2sv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib2sv) },
    Command{ .name = "glVertexAttrib3d", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3d) },
    Command{ .name = "glVertexAttrib3dv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3dv) },
    Command{ .name = "glVertexAttrib3f", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3f) },
    Command{ .name = "glVertexAttrib3fv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3fv) },
    Command{ .name = "glVertexAttrib3s", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3s) },
    Command{ .name = "glVertexAttrib3sv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib3sv) },
    Command{ .name = "glVertexAttrib4Nbv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nbv) },
    Command{ .name = "glVertexAttrib4Niv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Niv) },
    Command{ .name = "glVertexAttrib4Nsv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nsv) },
    Command{ .name = "glVertexAttrib4Nub", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nub) },
    Command{ .name = "glVertexAttrib4Nubv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nubv) },
    Command{ .name = "glVertexAttrib4Nuiv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nuiv) },
    Command{ .name = "glVertexAttrib4Nusv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4Nusv) },
    Command{ .name = "glVertexAttrib4bv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4bv) },
    Command{ .name = "glVertexAttrib4d", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4d) },
    Command{ .name = "glVertexAttrib4dv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4dv) },
    Command{ .name = "glVertexAttrib4f", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4f) },
    Command{ .name = "glVertexAttrib4fv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4fv) },
    Command{ .name = "glVertexAttrib4iv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4iv) },
    Command{ .name = "glVertexAttrib4s", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4s) },
    Command{ .name = "glVertexAttrib4sv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4sv) },
    Command{ .name = "glVertexAttrib4ubv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4ubv) },
    Command{ .name = "glVertexAttrib4uiv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4uiv) },
    Command{ .name = "glVertexAttrib4usv", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttrib4usv) },
    Command{ .name = "glVertexAttribPointer", .ptr = @ptrCast(**const c_void, &namespace.glVertexAttribPointer) },
    Command{ .name = "glUniformMatrix2x3fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix2x3fv) },
    Command{ .name = "glUniformMatrix3x2fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix3x2fv) },
    Command{ .name = "glUniformMatrix2x4fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix2x4fv) },
    Command{ .name = "glUniformMatrix4x2fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix4x2fv) },
    Command{ .name = "glUniformMatrix3x4fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix3x4fv) },
    Command{ .name = "glUniformMatrix4x3fv", .ptr = @ptrCast(**const c_void, &namespace.glUniformMatrix4x3fv) },
    Command{ .name = "glIsRenderbuffer", .ptr = @ptrCast(**const c_void, &namespace.glIsRenderbuffer) },
    Command{ .name = "glBindRenderbuffer", .ptr = @ptrCast(**const c_void, &namespace.glBindRenderbuffer) },
    Command{ .name = "glDeleteRenderbuffers", .ptr = @ptrCast(**const c_void, &namespace.glDeleteRenderbuffers) },
    Command{ .name = "glGenRenderbuffers", .ptr = @ptrCast(**const c_void, &namespace.glGenRenderbuffers) },
    Command{ .name = "glRenderbufferStorage", .ptr = @ptrCast(**const c_void, &namespace.glRenderbufferStorage) },
    Command{ .name = "glGetRenderbufferParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glGetRenderbufferParameteriv) },
    Command{ .name = "glIsFramebuffer", .ptr = @ptrCast(**const c_void, &namespace.glIsFramebuffer) },
    Command{ .name = "glBindFramebuffer", .ptr = @ptrCast(**const c_void, &namespace.glBindFramebuffer) },
    Command{ .name = "glDeleteFramebuffers", .ptr = @ptrCast(**const c_void, &namespace.glDeleteFramebuffers) },
    Command{ .name = "glGenFramebuffers", .ptr = @ptrCast(**const c_void, &namespace.glGenFramebuffers) },
    Command{ .name = "glCheckFramebufferStatus", .ptr = @ptrCast(**const c_void, &namespace.glCheckFramebufferStatus) },
    Command{ .name = "glFramebufferTexture1D", .ptr = @ptrCast(**const c_void, &namespace.glFramebufferTexture1D) },
    Command{ .name = "glFramebufferTexture2D", .ptr = @ptrCast(**const c_void, &namespace.glFramebufferTexture2D) },
    Command{ .name = "glFramebufferTexture3D", .ptr = @ptrCast(**const c_void, &namespace.glFramebufferTexture3D) },
    Command{ .name = "glFramebufferRenderbuffer", .ptr = @ptrCast(**const c_void, &namespace.glFramebufferRenderbuffer) },
    Command{ .name = "glGetFramebufferAttachmentParameteriv", .ptr = @ptrCast(**const c_void, &namespace.glGetFramebufferAttachmentParameteriv) },
    Command{ .name = "glGenerateMipmap", .ptr = @ptrCast(**const c_void, &namespace.glGenerateMipmap) },
    Command{ .name = "glBlitFramebuffer", .ptr = @ptrCast(**const c_void, &namespace.glBlitFramebuffer) },
    Command{ .name = "glRenderbufferStorageMultisample", .ptr = @ptrCast(**const c_void, &namespace.glRenderbufferStorageMultisample) },
    Command{ .name = "glFramebufferTextureLayer", .ptr = @ptrCast(**const c_void, &namespace.glFramebufferTextureLayer) },
};
