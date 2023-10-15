/// Implements a backend for a Mersenne prime field.
/// Zig makes this extra easy because we can literally just use an arbitrary width integer size 
/// and then invoke overflowing arithmetic. All we really need is to include computation of inverses.
pub fn Mersenne(comptime T: type) type {
    return struct {
        value: T,

        pub fn new(value: T) Mersenne(T) {
            return Mersenne(T){
                .value = value,
            };
        }

        /// Compute the inverse with Fermat's Little Theorem.
        /// Fermat's Little Theorem states that a^(p-1) = 1 mod p,
        /// therefore, a^(p-2) * a = 1 mod p, or a^(p-2) = a^-1 mod p.
        pub fn inverse_flt(self: Mersenne(T)) Mersenne(T) void {

        }

        /// Compute the inverse with the Extended Euclidean algorithm.
        /// Kinda just putting this here cause I'd like to bench it.
        pub fn inverse_xgcd(self: Mersenne(T)) Mersenne(T) void {

        }

        pub fn add(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            return Mersenne(T){
                .value = @addWithOverflow(self.value, other.value),
            };
        }

        pub fn addAssign(self: Mersenne(T), other: Mersenne(T)) void {
            self.value = @addWithOverflow(self.value, other.value);
        }

        pub fn sub(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            return Mersenne(T){
                .value = @subWithOverflow(self.value, other.value),
            };
        }

        pub fn subAssign(self: Mersenne(T), other: Mersenne(T)) void {
            self.value = @subWithOverflow(self.value, other.value);
        }

        pub fn mul(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            return Mersenne(T){
                .value = @mulWithOverflow(self.value, other.value),
            };
        }

        pub fn mulAssign(self: Mersenne(T), other: Mersenne(T)) void {
            self.value = @mulWithOverflow(self.value, other.value);
        }

        pub fn div(self: Mersenne(T), other: Mersenne(T)) Mersenne(T) {
            return Mersenne(T){
                .value = @mulWithOverflow(self.value, other.value.inverse_flt()),
            };
        }

        pub fn subAssign(self: Mersenne(T), other: Mersenne(T)) void {
            self.value = @mulWithOverflow(self.value, other.value.inverse_flt());
        }
    };
}
