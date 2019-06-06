pub const Mat4x4 = struct{
    data: [4][4]f32,

    /// matrix multiplication
    pub fn mult(m: *const Mat4x4, other: *const Mat4x4) Mat4x4 {
        return Mat4x4{
            .data = [][4]f32{
                []f32{
                    m.data[0][0]*other.data[0][0] + m.data[0][1]*other.data[1][0] + m.data[0][2]*other.data[2][0] + m.data[0][3]*other.data[3][0],
                    m.data[0][0]*other.data[0][1] + m.data[0][1]*other.data[1][1] + m.data[0][2]*other.data[2][1] + m.data[0][3]*other.data[3][1],
                    m.data[0][0]*other.data[0][2] + m.data[0][1]*other.data[1][2] + m.data[0][2]*other.data[2][2] + m.data[0][3]*other.data[3][2],
                    m.data[0][0]*other.data[0][3] + m.data[0][1]*other.data[1][3] + m.data[0][2]*other.data[2][3] + m.data[0][3]*other.data[3][3],
                },
                []f32{
                    m.data[1][0]*other.data[0][0] + m.data[1][1]*other.data[1][0] + m.data[1][2]*other.data[2][0] + m.data[1][3]*other.data[3][0],
                    m.data[1][0]*other.data[0][1] + m.data[1][1]*other.data[1][1] + m.data[1][2]*other.data[2][1] + m.data[1][3]*other.data[3][1],
                    m.data[1][0]*other.data[0][2] + m.data[1][1]*other.data[1][2] + m.data[1][2]*other.data[2][2] + m.data[1][3]*other.data[3][2],
                    m.data[1][0]*other.data[0][3] + m.data[1][1]*other.data[1][3] + m.data[1][2]*other.data[2][3] + m.data[1][3]*other.data[3][3],
                },
                []f32{
                    m.data[2][0]*other.data[0][0] + m.data[2][1]*other.data[1][0] + m.data[2][2]*other.data[2][0] + m.data[2][3]*other.data[3][0],
                    m.data[2][0]*other.data[0][1] + m.data[2][1]*other.data[1][1] + m.data[2][2]*other.data[2][1] + m.data[2][3]*other.data[3][1],
                    m.data[2][0]*other.data[0][2] + m.data[2][1]*other.data[1][2] + m.data[2][2]*other.data[2][2] + m.data[2][3]*other.data[3][2],
                    m.data[2][0]*other.data[0][3] + m.data[2][1]*other.data[1][3] + m.data[2][2]*other.data[2][3] + m.data[2][3]*other.data[3][3],
                },
                []f32{
                    m.data[3][0]*other.data[0][0] + m.data[3][1]*other.data[1][0] + m.data[3][2]*other.data[2][0] + m.data[3][3]*other.data[3][0],
                    m.data[3][0]*other.data[0][1] + m.data[3][1]*other.data[1][1] + m.data[3][2]*other.data[2][1] + m.data[3][3]*other.data[3][1],
                    m.data[3][0]*other.data[0][2] + m.data[3][1]*other.data[1][2] + m.data[3][2]*other.data[2][2] + m.data[3][3]*other.data[3][2],
                    m.data[3][0]*other.data[0][3] + m.data[3][1]*other.data[1][3] + m.data[3][2]*other.data[2][3] + m.data[3][3]*other.data[3][3],
                },
            },
        };
    }

    /// Builds a translation 4 * 4 matrix created from a vector of 3 components.
    /// Input matrix multiplied by this translation matrix.
    pub fn translate(m: *const Mat4x4, x: f32, y: f32, z: f32) Mat4x4 {
        return Mat4x4{
            .data = [][4]f32 {
                []f32{m.data[0][0], m.data[0][1], m.data[0][2], m.data[0][3] + m.data[0][0] * x + m.data[0][1] * y + m.data[0][2] * z},
                []f32{m.data[1][0], m.data[1][1], m.data[1][2], m.data[1][3] + m.data[1][0] * x + m.data[1][1] * y + m.data[1][2] * z},
                []f32{m.data[2][0], m.data[2][1], m.data[2][2], m.data[2][3] + m.data[2][0] * x + m.data[2][1] * y + m.data[2][2] * z},
                []f32{m.data[3][0], m.data[3][1], m.data[3][2], m.data[3][3]},
            },
        };
    }

    /// Builds a scale 4 * 4 matrix created from 3 scalars.
    /// Input matrix multiplied by this scale matrix.
    pub fn scale(m: *const Mat4x4, x: f32, y: f32, z: f32) Mat4x4 {
        return Mat4x4{
            .data = [][4]f32{
                []f32{m.data[0][0] * x, m.data[0][1] * y, m.data[0][2] * z, m.data[0][3]},
                []f32{m.data[1][0] * x, m.data[1][1] * y, m.data[1][2] * z, m.data[1][3]},
                []f32{m.data[2][0] * x, m.data[2][1] * y, m.data[2][2] * z, m.data[2][3]},
                []f32{m.data[3][0] * x, m.data[3][1] * y, m.data[3][2] * z, m.data[3][3]},
            },
        };
    }

    pub fn transpose(m: *const Mat4x4) Mat4x4 {
        return Mat4x4{
            .data = [][4]f32 {
                []f32{m.data[0][0], m.data[1][0], m.data[2][0], m.data[3][0]},
                []f32{m.data[0][1], m.data[1][1], m.data[2][1], m.data[3][1]},
                []f32{m.data[0][2], m.data[1][2], m.data[2][2], m.data[3][2]},
                []f32{m.data[0][3], m.data[1][3], m.data[2][3], m.data[3][3]},
            },
        };
    }
};

pub const mat4x4_identity = Mat4x4{
    .data = [][4]f32{
        []f32{1.0, 0.0, 0.0, 0.0},
        []f32{0.0, 1.0, 0.0, 0.0},
        []f32{0.0, 0.0, 1.0, 0.0},
        []f32{0.0, 0.0, 0.0, 1.0},
    },
};

/// Creates a matrix for an orthographic parallel viewing volume.
pub fn mat4x4_ortho(left: f32, right: f32, bottom: f32, top: f32) Mat4x4 {
    var m = mat4x4_identity;
    m.data[0][0] = 2.0 / (right - left);
    m.data[1][1] = 2.0 / (top - bottom);
    m.data[2][2] = -1.0;
    m.data[0][3] = -(right + left) / (right - left);
    m.data[1][3] = -(top + bottom) / (top - bottom);
    return m;
}
