/// Extended euclidian algorithm which returns the inverse of `x` for a modulus `y`.
pub fn mod_inverse(comptime T: type, x: T, y: T) T {
    var old_r = y;
    var r = x;
    var old_s = 1;
    var s = 0;

    while (r != 0) {
        const quotient = old_r / r;

        const tmp_r = r;
        r = old_r - quotient * r;
        old_r = tmp_r;

        const tmp_s = s;
        s = old_s - quotient * s;
        old_s = tmp_s;
    }

    return old_s;
}

/// Implements field arithmetic automatically for a given modulus.
pub fn Field(comptime T: type) type {
    return struct {
        modulus: T,
        value: T,

        pub fn new(value: T, modulus: T) Field(T) {
            var v = value;
            while (v > modulus) {
                v -= modulus;
            }
            return Field(T){
                .modulus = modulus,
                .value = v,
            };
        }

        pub fn neg(self: Field(T)) Field(T) {
            const new_value = self.modulus - self.value;

            return Field(T){
                .modulus = self.modulus,
                .value = new_value,
            };
        }

        pub fn negAssign(self: *Field(T)) void {
            self.value = self.modulus - self.value;
        }

        pub fn inverse(self: Field(T)) Field(T) {
            return Field(T){
                .modulus = self.modulus,
                .value = mod_inverse(T, self.value, self.modulus),
            };
        }

        pub fn invert(self: *Field(T)) void {
            self.value = mod_inverse(T, self.value, self.modulus);
        }

        pub fn add(self: Field(T), other: Field(T)) Field(T) {
            var new_value = self.value + other.value;
            if (new_value >= self.modulus) {
                new_value -= self.modulus;
            }

            return Field(T){
                .modulus = self.modulus,
                .value = new_value,
            };
        }

        pub fn addAssign(self: *Field(T), other: Field(T)) void {
            self.value += other.value;
            if (self.value >= self.modulus) {
                self.value -= self.modulus;
            }
        }

        pub fn sub(self: Field(T), other: Field(T)) Field(T) {
            var new_value = self.value + other.neg();
            if (new_value >= self.modulus) {
                new_value -= self.modulus;
            }

            return Field(T){
                .modulus = self.modulus,
                .value = new_value,
            };
        }

        pub fn subAssign(self: *Field(T), other: Field(T)) void {
            self.value = self.value + other.neg();
            if (self.value >= self.modulus) {
                self.value -= self.modulus;
            }
        }

        pub fn mul(self: Field(T), other: Field(T)) Field(T) {
            if (other.value == 2) {
                var new_value = self.value << 1;
                while (new_value >= self.modulus) {
                    new_value -= self.modulus;
                }
                return Field(T){
                    .modulus = self.modulus,
                    .value = new_value,
                };
            } else {
                unreachable;
            }
        }
    };
}