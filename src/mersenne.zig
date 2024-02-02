const std = @import("std");

// 2^31 - 1
const m31_modulus = 2147483647;

/// Implements the Mersenne-31 prime field.
pub const M31 = struct {
    value: u64,

    /// XXX: i cant seem to crack it right now but i wonder if we can comptime derive a
    /// 'multiplication-type' which would allow us to hold values in smaller registers and
    /// then efficiently create bigger registers for the multiplication results.
    ///
    /// as a sidenote, this backend is likely really only useful for M31 so it isn't a huge
    /// deal, and from what i can see on agner fog's benches there's no slowdown on 32 vs 64
    /// bit muls.
    pub fn new(value: u64) M31 {
        var v = value;
        while (v > m31_modulus) {
            v -= m31_modulus;
        }

        return M31{
            .value = v,
        };
    }

    pub fn isZero(self: M31) bool {
        return self.value == 0;
    }

    pub fn neg(self: M31) M31 {
        const new_value = m31_modulus - self.value;

        return M31{
            .value = new_value,
        };
    }

    pub fn negAssign(self: *M31) void {
        self.*.value = m31_modulus - self.value;
    }

    /// Compute the inverse with Fermat's Little Theorem.
    /// Fermat's Little Theorem states that a^(p-1) = 1 mod p,
    /// therefore, a^(p-2) * a = 1 mod p, or a^(p-2) = a^-1 mod p.
    /// For M31, we thus need to compute a^2147483646.
    /// Taken from https://github.com/Plonky3/Plonky3/blob/main/mersenne-31/src/lib.rs#L217.
    pub fn inverse_flt(self: M31) M31 {
        var result = self;
        const a1 = self;
        // a^101
        result = result.square().square().mul(a1);

        const a1111 = result.square().mul(result);
        const a11111111 = a1111.square().square().square().square().mul(a1111);
        const a111111110000 = a11111111.square().square().square().square();
        const a111111111111 = a111111110000.mul(a1111);
        const a1111111111111111 = a111111110000.square().square().square().square().mul(a11111111);
        const a1111111111111111111111111111 = a1111111111111111.square().square().square().square().square().square().square().square().square().square().square().square().mul(a111111111111);
        result.mulAssign(a1111111111111111111111111111.square().square().square());

        return result;
    }

    /// Compute the inverse with the Extended Euclidean algorithm.
    /// Kinda just putting this here cause I'd like to bench it.
    //pub fn inverse_xgcd(self: M31) M31 void {

    //}

    inline fn addInner(value: *u64, other: u64) void {
        value.* += other;
        if (value.* >= m31_modulus) {
            value.* -= m31_modulus;
        }
    }

    pub fn add(self: M31, other: M31) M31 {
        var new_value = self.value;
        addInner(&new_value, other.value);
        return M31{
            .value = new_value,
        };
    }

    pub fn addAssign(self: *M31, other: M31) void {
        addInner(&self.value, other.value);
    }

    pub fn sub(self: M31, other: M31) M31 {
        return self.add(other.neg());
    }

    pub fn subAssign(self: M31, other: M31) void {
        self.addAssign(other.neg());
    }

    // https://thomas-plantard.github.io/pdf/Plantard21.pdf, Algorithm 3
    inline fn mulInner(value: *u64, other: u64) void {
        value.* *= other;
        const result_hi = value.* >> 31;
        const result_lo = value.* & ((1 << 31) - 1);
        value.* = result_lo + result_hi;
        if (value.* > m31_modulus) {
            value.* -= m31_modulus;
        }
    }

    pub fn mul(self: M31, other: M31) M31 {
        var new_value = self.value;
        mulInner(&new_value, other.value);
        return M31{
            .value = new_value,
        };
    }

    pub fn mulAssign(self: *M31, other: M31) void {
        mulInner(&self.value, other.value);
    }

    pub fn div(self: M31, other: M31) M31 {
        var inv_other = other;
        inv_other.value = inv_other.value.inverse_flt();
        return self.mul(inv_other);
    }

    pub fn divAssign(self: *M31, other: M31) void {
        var inv_other = other;
        inv_other.value = inv_other.value.inverse_flt();
        self.mulAssign(inv_other);
    }

    pub fn square(self: M31) M31 {
        return self.mul(self);
    }
};

const testing = std.testing;
const add = @import("testing.zig").add;
const mul = @import("testing.zig").mul;
const invert = @import("testing.zig").invert;

test "basic add functionality" {
    try testing.expect(add(2147483646, 2147483646).value == 2147483645);
    try testing.expect(add(2147483646, 1).value == 0);
}

test "mul by 2" {
    try testing.expect(mul(2147483646, 2).value == 2147483645);
}

test "inverse" {
    try testing.expect(invert(137489124).value == 1);
}
