const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayHashMap = std.AutoArrayHashMap;
const MVPolynomial = @import("mvpoly.zig").MVPolynomial;

const PolynomialError = error{
    NoQuotientValue,
};

fn QuoRem(comptime T: type) type {
    return struct {
        quotient: Polynomial(T),
        remainder: Polynomial(T),
    };
}

/// Defines a univariate polynomial with any kind of field element.
/// Makes no distinction between dense or sparse populations but tries to be as efficient
/// as possible despite this.
///
/// Coefficients are considered to be rising in degree.
// XXX: guards for empty polys
pub fn Polynomial(comptime T: type) type {
    return struct {
        elements: ArrayList(T),

        pub fn new(elements: ArrayList(T)) Polynomial(T) {
            return Polynomial(T){
                .elements = elements,
            };
        }

        pub fn isZero(self: Polynomial(T)) bool {
            return self.degree() == 0;
        }

        pub fn degree(self: Polynomial(T)) usize {
            var max_index: isize = -1;
            for (0.., self) |i, v| {
                if (!v.isZero()) {
                    max_index = i;
                }
            }
            return max_index;
        }

        pub fn neg(self: Polynomial(T)) Polynomial(T) {
            var new_value = self;
            for (&new_value) |*v| {
                v.negAssign();
            }

            return new_value;
        }

        pub fn negAssign(self: *Polynomial(T)) void {
            for (&self) |*v| {
                v.negAssign();
            }
        }

        inline fn addInner(value: *Polynomial(T), other: Polynomial(T)) void {
            const m = @max(value.elements.length(), other.elements.length());
            if (m > value.elements.length()) {
                value.elements.extend(m - value.elements.length());
            }

            if (m > other.elements.length()) {
                other.elements.extend(m - other.elements.length());
            }

            for (0.., value.elements, other.elements) |i, v1, v2| {
                value.elements.insert(i, v1.add(v2));
            }
        }

        pub fn add(self: Polynomial(T), other: Polynomial(T)) Polynomial(T) {
            var new_value = self;
            addInner(new_value, other);
            return new_value;
        }

        pub fn addAssign(self: *Polynomial(T), other: Polynomial(T)) void {
            addInner(self, other);
        }

        pub fn sub(self: Polynomial(T), other: Polynomial(T)) Polynomial(T) {
            var new_value = self;
            const new_other = other.neg();
            addInner(new_value, new_other);
            return new_value;
        }

        pub fn subInner(self: *Polynomial(T), other: Polynomial(T)) void {
            const new_other = other.neg();
            addInner(self, new_other);
        }

        inline fn mulInner(value: Polynomial(T), other: Polynomial(T), allocator: Allocator) Polynomial(T) {
            const length = value.elements.length() + other.elements.length() - 1;
            var list = ArrayList(T).init(allocator);
            list.appendNTimes(T.new(0), length);
            var result = Polynomial(T){
                .elements = list,
            };

            for (0.., value.elements) |i, v1| {
                // sparse poly optimization
                if (v1.isZero()) {
                    continue;
                }

                for (0.., other.elements) |j, v2| {
                    result.elements.items[i + j].addAssign(v1.mul(v2));
                }
            }

            return result;
        }

        pub fn mul(self: Polynomial(T), other: Polynomial(T), allocator: Allocator) Polynomial(T) {
            return mulInner(self, other, allocator);
        }

        pub fn mulAssign(self: *Polynomial(T), other: Polynomial(T), allocator: Allocator) Polynomial(T) {
            self = mulInner(self, other, allocator);
        }

        inline fn divInner(numerator: Polynomial(T), denominator: Polynomial(T), allocator: Allocator) ?QuoRem(T) {
            if (denominator.degree() == -1) {
                return null;
            }

            if (numerator.degree() < denominator.degree()) {
                return QuoRem(T){ .quotient = Polynomial(T).new(ArrayList(T).init(allocator)), .remainder = numerator };
            }

            var remainder = numerator;
            var q_list = ArrayList(T).init(allocator);
            const size = numerator.degree() - denominator.degree() + 1;
            q_list.appendNTimes(T.new(0), size);
            var quotient = Polynomial(T).new(q_list);

            for (0..size) |_| {
                if (remainder.degree() < denominator.degree()) {
                    break;
                }

                const coeff = remainder.leadingCoefficient().div(denominator.leadingCoefficient());
                const shift = remainder.degree() - denominator.degree();

                var sub_list = ArrayList(T).init(allocator);
                sub_list.appendNTimes(T.new(0), shift);
                sub_list.append(coeff);
                const subtractee = Polynomial(T).new(sub_list);
                defer subtractee.deinit();

                quotient.elements.items[shift] = coeff;
                remainder.subAssign(subtractee);
            }

            return QuoRem(T){ .quotient = quotient, .remainder = remainder };
        }

        pub fn div(self: Polynomial(T), other: Polynomial(T)) ?QuoRem(T) {
            return divInner(self, other);
        }

        pub fn divAssign(self: *Polynomial(T), other: Polynomial(T)) !void {
            const quorem = divInner(self, other) orelse return PolynomialError.NoQuotientValue;
            self = quorem.quotient;
        }

        pub fn pow(self: Polynomial(T), exponent: u64, allocator: Allocator) !Polynomial(T) {
            if (self.isZero()) {
                var a_list = ArrayList(T).init(allocator);
                a_list.push(T.new(0));
                const acc = Polynomial(T).new(a_list);
                return acc;
            }

            if (exponent == 0) {
                var a_list = ArrayList(T).init(allocator);
                a_list.push(T.new(1));
                const acc = Polynomial(T).new(a_list);
                return acc;
            }

            var a_list = ArrayList(T).init(allocator);
            a_list.push(T.new(1));
            var acc = Polynomial(T).new(a_list);
            for (0..64) |i| {
                const j = 63 - i;
                acc.mulAssign(acc);
                if ((1 << j) & exponent != 0) {
                    acc.mulAssign(self);
                }
            }

            return acc;
        }

        pub fn eval(self: Polynomial(T), point: T) T {
            var result = self.elements.items[0];
            const base_point = point;

            for (self.elements) |v| {
                result.addAssign(v.mul(point));
                point.mulAssign(base_point);
            }
        }

        pub fn leadingCoefficient(self: Polynomial(T)) T {
            return self.elements.items[self.degree()];
        }

        // Simple iterative method
        // NOTE: should be updated to use cooley tukey FFT at some point
        pub fn interpolate(domain: []T, values: []T, allocator: Allocator) Polynomial(T) {
            var x_list = ArrayList(T).init(allocator);
            x_list.push(T.new(0));
            x_list.push(T.new(1));
            const x = Polynomial(T).new(x_list);
            defer x.deinit();

            var acc = Polynomial(T).new(ArrayList(T).init(allocator));
            for (0.., domain) |i, _| {
                var product_list = ArrayList(T).init(allocator);
                product_list.push(values[i]);
                var product = Polynomial(T).new(product_list);

                for (0.., domain) |j, _| {
                    if (j == i) {
                        continue;
                    }

                    var a_list = ArrayList(T).init(allocator);
                    a_list.push(domain[j]);
                    const a = Polynomial(T).new(a_list);

                    var b_list = ArrayList(T).init(allocator);
                    b_list.push(domain[i].sub(domain[j]));
                    var b = Polynomial(T).new(b_list);
                    b.negAssign();
                    product.mulAssign(x.sub(a).mul(b));

                    a.deinit();
                    b.deinit();
                }

                acc.addAssign(product);
                product.deinit();
            }

            return acc;
        }

        pub fn zerofierDomain(domain: []T, allocator: Allocator) Polynomial(T) {
            var a_list = ArrayList(T).init(allocator);
            a_list.push(T.new(0), T.new(1));
            const x = Polynomial(T).new(a_list);
            defer x.deinit();

            var b_list = ArrayList(T).init(allocator);
            b_list.push(T.new(1));
            var acc = Polynomial(T).new(b_list);

            for (0.., domain) |i, _| {
                var c_list = ArrayList(T).init(allocator);
                c_list.push(T.new(i));
                const c = Polynomial(T).new(c_list);
                const t = x.sub(c);
                acc.mulAssign(t);
                c.deinit();
            }

            return acc;
        }

        pub fn scale(self: *Polynomial(T), factor: T) void {
            var f = T.new(1);
            for (&self.elements) |*el| {
                el.*.mulAssign(f);
                f.mulAssign(factor);
            }
        }

        pub fn testColinearity(points: [3][2]T, allocator: Allocator) bool {
            var domain: [3]T = undefined;
            for (0.., points) |i, p| {
                domain[i] = p[0];
            }

            var values: [3]T = undefined;
            for (0.., points) |i, p| {
                values[i] = p[1];
            }

            const p = interpolate(domain, values, allocator);
            defer p.deinit();
            return p.degree() <= 1;
        }

        pub fn lift(self: Polynomial(T), index: u64, allocator: Allocator) MVPolynomial(T) {
            if (self.isZero()) {
                return MVPolynomial(T).newZero(allocator);
            }

            var list = ArrayList(T).init(allocator);
            for (0..index) |_| {
                list.append(0) catch unreachable;
            }
            list.append(1) catch unreachable;

            var map = ArrayHashMap(ArrayList(u64), T).init(allocator);
            map.put(list, T.new(1)) catch unreachable;
            var x = MVPolynomial(T).new(map) catch unreachable;
            defer x.deinit();
            var acc = MVPolynomial(T).newZero(allocator);

            for (0.., self.elements.items) |i, coeff| {
                acc = acc.add(MVPolynomial(T).constant(coeff, allocator).mul(x.pow(i)));
            }
            return acc;
        }

        pub fn deinit(self: Polynomial(T)) void {
            self.elements.deinit();
        }
    };
}
