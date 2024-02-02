const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayHashMap = std.AutoArrayHashMap;

const MVPolynomialError = error{
    VariableSizeMismatch,
};

pub fn MVPolynomial(comptime T: type) type {
    return struct {
        num_vars: u64,
        elements: ArrayHashMap(ArrayList(u64), T),

        pub fn new(elements: ArrayHashMap(ArrayList(u64), T)) !MVPolynomial(T) {
            var num_vars: u64 = 0;
            for (0.., elements.keys()) |i, k| {
                if (i == 0) {
                    num_vars = k.items.len;
                } else {
                    if (num_vars != k.items.len) {
                        return MVPolynomialError.VariableSizeMismatch;
                    }
                }
            }

            return MVPolynomial(T){
                .num_vars = num_vars,
                .elements = elements,
            };
        }

        pub fn newZero(
            allocator: Allocator,
        ) MVPolynomial(T) {
            return MVPolynomial(T){
                .num_vars = 1,
                .elements = ArrayHashMap(ArrayList(u64), T).init(allocator),
            };
        }

        pub fn isZero(self: MVPolynomial(T)) bool {
            for (self.elements.variables()) |v| {
                if (!v.isZero()) {
                    return false;
                }
            }

            return true;
        }

        pub fn neg(self: MVPolynomial(T)) MVPolynomial(T) {
            var new_value = self;
            for (new_value.elements.keys()) |k| {
                var v_ptr = new_value.elements.getPtr(k).?;
                v_ptr.*.negAssign();
            }

            return new_value;
        }

        inline fn addInner(self: MVPolynomial(T), other: MVPolynomial(T), allocator: Allocator) MVPolynomial(T) {
            const l = @max(self.num_vars, other.num_vars);
            var map = ArrayHashMap(ArrayList(u64), T).init(allocator);

            for (self.elements.keys()) |k| {
                var arr = ArrayList(u64).init(allocator);
                for (k.items) |e| {
                    arr.append(e) catch unreachable;
                }

                while (arr.items.len < l) {
                    arr.append(0) catch unreachable;
                }

                map.put(arr, self.elements.get(k).?) catch unreachable;
            }

            for (other.elements.keys()) |k| {
                var arr = ArrayList(u64).init(allocator);
                for (k.items) |e| {
                    arr.append(e) catch unreachable;
                }

                while (arr.items.len < l) {
                    arr.append(0) catch unreachable;
                }

                const result = map.getOrPut(arr) catch unreachable;
                if (result.found_existing) {
                    result.value_ptr.*.addAssign(other.elements.get(k).?);
                } else {
                    result.value_ptr.* = other.elements.get(k).?;
                }
            }

            return MVPolynomial(T).new(map) catch unreachable;
        }

        pub fn add(self: MVPolynomial(T), other: MVPolynomial(T), allocator: Allocator) MVPolynomial(T) {
            return self.addInner(other, allocator);
        }

        pub fn sub(self: MVPolynomial(T), other: MVPolynomial(T), allocator: Allocator) MVPolynomial(T) {
            var other_neg = other.neg();
            return self.addInner(other_neg, allocator);
        }

        inline fn mulInner(self: MVPolynomial(T), other: MVPolynomial(T), allocator: Allocator) MVPolynomial(T) {
            const max_vars = @max(self.num_vars, other.num_vars);
            var map = ArrayHashMap([]u64, T).init(allocator);

            for (self.keys) |k| {
                for (other.keys) |j| {
                    var exponent: [max_vars]u64 = 0 ** max_vars;
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

            return MVPolynomial(T).new(map) catch unreachable;
        }

        pub fn mul(self: MVPolynomial(T), other: MVPolynomial(T), allocator: Allocator) MVPolynomial(type, T) {
            return mulInner(self, other, allocator);
        }

        pub fn pow(self: MVPolynomial(T), exponent: u64, allocator: Allocator) MVPolynomial(T) {
            if (self.isZero()) {
                return self.newZero(allocator);
            }

            const exp: [self.num_vars]u64 = 0 ** self.num_vars;
            var map = ArrayHashMap(ArrayList(u64), T).init(allocator);
            map.put(exp, T.new(1));
            var acc = MVPolynomial(T).new(map);

            while (exponent != 0) {
                acc.mulAssign(acc);
                if (exponent & 1 == 1) {
                    acc.mulAssign(self);
                }
                exponent >>= 1;
            }

            return acc;
        }

        pub fn constant(element: T, allocator: Allocator) MVPolynomial(T) {
            var map = ArrayHashMap(ArrayList(u64), T).init(allocator);
            var arr = ArrayList(u64).init(allocator);
            arr.append(0) catch unreachable;
            map.put(arr, element) catch unreachable;
            return MVPolynomial(T).new(map) catch unreachable;
        }

        // TODO: lift, eval, symbolic eval

        pub fn deinit(self: *MVPolynomial(T)) void {
            self.elements.deinit();
        }
    };
}

const testing = std.testing;
const M31 = @import("mersenne.zig").M31;
const test_allocator = testing.allocator;

test "init" {
    var p = MVPolynomial(M31).newZero(test_allocator);
    var constant = MVPolynomial(M31).constant(M31.new(123), test_allocator);
    defer p.deinit();
    defer constant.deinit();
    var result = constant.add(p, test_allocator);
    defer result.deinit();
    var result2 = constant.sub(p, test_allocator);
    defer result2.deinit();
}
