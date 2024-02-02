const M31 = @import("mersenne.zig").M31;

pub fn add(a: u64, b: u64) M31 {
    const a_field = M31.new(a);
    const b_field = M31.new(b);
    return a_field.add(b_field);
}

pub fn mul(a: u64, b: u64) M31 {
    const a_field = M31.new(a);
    const b_field = M31.new(b);
    return a_field.mul(b_field);
}

pub fn invert(a: u64) M31 {
    const a_field = M31.new(a);
    const a_field_inv = a_field.inverse_flt();
    return a_field.mul(a_field_inv);
}
