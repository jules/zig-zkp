const std = @import("std");
const M31 = @import("mersenne.zig").M31;
const testing = std.testing;

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

test "basic add functionality" {
    try testing.expect(add(2147483646, 2147483646).value == 2147483645);
}

test "mul by 2" {
    try testing.expect(mul(2147483646, 2).value == 2147483645);
}

test "inverse" {
    try testing.expect(invert(137489124).value == 1);
}
