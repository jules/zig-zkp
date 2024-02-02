const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayHashMap = std.AutoArrayHashMap;

pub fn MVPolynomial(comptime L: type, comptime T: type) type {
    return struct {
        elements: ArrayHashMap([L]u64, T),

        pub fn new(elements: ArrayHashMap([L]u64, T)) MVPolynomial(L, T) {
            return MVPolynomial(L, T){
                .elements = elements,
            };
        }

        pub fn newZero(allocator: Allocator) MVPolynomial(L, T) {
            return MVPolynomial(L, T){
                .elements = ArrayHashMap([L]u64, T).init(allocator),
            };
        }

        pub fn isZero(self: MVPolynomial(L, T)) bool {
            for (self.elements.variables()) |v| {
                if (!v.isZero()) {
                    return false;
                }
            }

            return true;
        }

        pub fn numVariables(self: MVPolynomial(L, T)) type {
            _ = self; // ugly
            return L;
        }

        pub fn neg(self: MVPolynomial(L, T)) MVPolynomial(L, T) {
            var new_value = self;
            for (new_value.values()) |v| {
                v.negAssign();
            }

            return new_value;
        }

        pub fn negAssign(self: *MVPolynomial(L, T)) void {
            for (self.values()) |v| {
                v.negAssign();
            }
        }

        inline fn addInner(self: MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) MVPolynomial(type, T) {
            const other_num_vars = other.numVariables();
            const num_vars = @max(L, other_num_vars);
            var map = ArrayHashMap([num_vars]u64, T).init(allocator);

            for (self.elements.keys()) |k| {
                var pad: [num_vars]u64 = 0 ** num_vars;
                for (0.., k) |i, e| {
                    pad[i] = e;
                }

                map.put(pad, self.elements.get(k));
            }

            for (other.elements.keys()) |k| {
                var pad: [num_vars]u64 = 0 ** num_vars;
                for (0.., k) |i, e| {
                    pad[i] = e;
                }

                var result = map.getOrPut(pad, self.keys.get(k));
                if (result.found_existing) {
                    result.value_ptr.* = result.value_ptr.* + self.elements.get(k);
                }
            }

            return MVPolynomial(num_vars, T).new(map);
        }

        pub fn add(self: MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) MVPolynomial(type, T) {
            return addInner(self, other, allocator);
        }

        pub fn addAssign(self: *MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) void {
            const new_value = addInner(self, other, allocator);
            self.* = new_value;
        }

        pub fn sub(self: MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) MVPolynomial(type, T) {
            var other_neg = other;
            other_neg.negAssign();
            return addInner(self, other_neg, allocator);
        }

        pub fn subAssign(self: *MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) void {
            var other_neg = other;
            other_neg.negAssign();
            const new_value = addInner(self, other_neg, allocator);
            self.* = new_value;
        }

        inline fn mulInner(self: MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) MVPolynomial(type, T) {
            const other_num_vars = other.numVariables();
            const num_vars = @max(L, other_num_vars);
            var map = ArrayHashMap([num_vars]u64, T).init(allocator);

            for (self.keys) |k| {
                for (other.keys) |j| {
                    var exponent: [num_vars]u64 = 0 ** num_vars;
                    for (0.., k) |i, e| {
                        exponent[i] = e;
                    }
                    for (0.., j) |i, e| {
                        exponent[i] = exponent[i] + e;
                    }

                    const m = self.elements.get(k).mul(other.elements.get(j));
                    var result = map.getOrPut(exponent, m);
                    if (result.found_existing) {
                        result.value_ptr.* = result.value_ptr.* + m;
                    }
                }
            }

            return MVPolynomial(num_vars, T).new(map);
        }

        pub fn mul(self: MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) MVPolynomial(type, T) {
            return mulInner(self, other, allocator);
        }

        pub fn mulAssign(self: *MVPolynomial(L, T), other: MVPolynomial(type, T), allocator: Allocator) void {
            const new_value = mulInner(self, other, allocator);
            self.* = new_value;
        }

        pub fn pow(self: MVPolynomial(L, T), exponent: u64, allocator: Allocator) MVPolynomial(L, T) {
            if (self.isZero()) {
                return self.newZero(allocator);
            }

            const exp: [L]u64 = 0 ** L;
            var map = ArrayHashMap([L]u64, T).init(allocator);
            map.put(exp, T.new(1));
            var acc = MVPolynomial(L, T).new(map);

            while (exponent != 0) {
                acc.mulAssign(acc);
                if (exponent & 1 == 1) {
                    acc.mulAssign(self);
                }
                exponent >>= 1;
            }

            return acc;
        }

        pub fn constant(element: T, allocator: Allocator) MVPolynomial(1, T) {
            var map = ArrayHashMap([1]u64, T).init(allocator);
            map.put([1]u64{0}, element);
            return MVPolynomial(1, T).new(map);
        }

        // TODO: lift, eval, symbolic eval

        pub fn deinit(self: MVPolynomial(L, T)) void {
            self.elements.deinit();
        }
    };
}
