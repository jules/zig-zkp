const std = @import("std");

/// Implements a backend for a Mersenne prime field.
pub fn Mersenne(comptime T: type) type {
    return struct {
        modulus: T,
        value: T,
        mul_bits: u16,
        num_bits: u16,
        mul_trunc: T,

        /// Creates a new Mersenne backend. The function expects the generic integer type to have
        /// 1 bit more width than the actual modulus for easy arithmetic implementations.
        /// XXX: can we enforce this?
        pub fn new(value: T, modulus: T) Mersenne(T) {
            var v = value;
            while (v > modulus) {
                v -= modulus;
            }

            var mul_bits = @typeInfo(T).Int.bits;
            mul_bits *= 2;

            const num_bits = @typeInfo(T).Int.bits - 1;
            const mul_trunc = (1 << num_bits) - 1;
            return Mersenne(T){
                .modulus = modulus,
                .value = v,
                .mul_bits = mul_bits,
                .num_bits = num_bits,
                .mul_trunc = mul_trunc,
            };
        }

        pub fn neg(self: Mersenne(T)) Mersenne(T) {
            const new_value = self.modulus - self.value;

            return Mersenne(T){
                .modulus = self.modulus,
                .value = new_value,
            };
        }

        pub fn negAssign(self: Mersenne(T)) void {
            self.value = self.modulus - self.value;
        }

        /// Compute the inverse with Fermat's Little Theorem.
        /// Fermat's Little Theorem states that a^(p-1) = 1 mod p,
        /// therefore, a^(p-2) * a = 1 mod p, or a^(p-2) = a^-1 mod p.
        //pub fn inverse_flt(self: Mersenne(T)) Mersenne(T) void {

        //}

        /// Compute the inverse with the Extended Euclidean algorithm.
        /// Kinda just putting this here cause I'd like to bench it.
        //pub fn inverse_xgcd(self: Mersenne(T)) Mersenne(T) void {

        //}

        inline fn addInner(value: *T, other: T, modulus: T) void {
            value.* += other;
            if (value.* >= modulus) {
                value.* -= modulus;
            }
        }

        pub fn add(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            var new_value = self.value;
            addInner(&new_value, other.value, self.modulus);
            return Mersenne(T){
                .modulus = self.modulus,
                .value = new_value,
                .mul_bits = self.mul_bits,
                .num_bits = self.num_bits,
                .mul_trunc = self.mul_trunc,
            };
        }

        pub fn addAssign(self: *Mersenne(T), other: Mersenne(T)) void {
            addInner(&self.value, other.value, self.modulus);
        }

        pub fn sub(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            return self.add(other.neg());
        }

        pub fn subAssign(self: Mersenne(T), other: Mersenne(T)) void {
            self.addAssign(other.neg());
        }

        // https://thomas-plantard.github.io/pdf/Plantard21.pdf, Algorithm 3
        inline fn mulInner(value: *T, other: T, modulus: T, num_bits: u16, mul_trunc: T) void {
            const t = comptime std.builtin.Type{
                .Int = std.builtin.Type.Int{
                    .signedness = std.builtin.Signedness.unsigned,
                    .bits = @typeInfo(T).Int.bits * 2,
                },
            };
            var result: @Type(t) = @as(@Type(t), value.*) * @as(@Type(t), other);
            const result_hi: T = @intCast(result >> @truncate(num_bits));
            const result_lo: T = @truncate(result & mul_trunc);
            value.* = result_lo + result_hi;
            if (value.* > modulus) {
                value.* -= modulus;
            }
        }

        pub fn mul(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            var new_value: T = self.value;
            mulInner(&new_value, other.value, self.modulus, self.num_bits, self.mul_trunc);
            return Mersenne(T){
                .modulus = self.modulus,
                .value = new_value,
                .mul_bits = self.mul_bits,
                .num_bits = self.num_bits,
                .mul_trunc = self.mul_trunc,
            };
        }

        pub fn mulAssign(self: *Mersenne(T), other: Mersenne(T)) void {
            mulInner(&self.value, other.value, self.modulus, self.num_bits, self.mul_trunc);
        }

        pub fn div(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            var inv_other = other;
            inv_other.value = inv_other.value.inverse_flt();
            return self.mul(inv_other);
        }

        pub fn divAssign(self: *Mersenne(T), other: Mersenne(T)) void {
            var inv_other = other;
            inv_other.value = inv_other.value.inverse_flt();
            self.mulAssign(inv_other);
        }
    };
}
