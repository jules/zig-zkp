const std = @import("std");
const Mersenne = @import("mersenne.zig").Mersenne;
const testing = std.testing;

pub fn add(a: u32, b: u32) Mersenne(u32) {
    const a_field = Mersenne(u32).new(a, 2147483647);
    const b_field = Mersenne(u32).new(b, 2147483647);
    return a_field.add(b_field);
}

pub fn mul(a: u32, b: u32) Mersenne(u32) {
    const a_field = Mersenne(u32).new(a, 2147483647);
    const b_field = Mersenne(u32).new(b, 2147483647);
    return a_field.mul(b_field);
}

test "basic add functionality" {
    try testing.expect(add(2147483646, 2147483646).value == 2147483645);
}

test "mul by 2" {
    try testing.expect(mul(2147483646, 2).value == 2147483645);
}
