const std = @import("std");
const Allocator = std.mem.Allocator;

const PolynomialError = error {
    NoQuotientValue,
};

const QuoRem = struct {
    quotient: Polynomial,
    remainder: Polynomial,
};

/// Defines a polynomial with any kind of field element.
/// Makes no distinction between dense or sparse populations but tries to be as efficient
/// as possible despite this.
///
/// Coefficients are considered to be rising in degree.
/// XXX: guards for empty polys
pub const Polynomial = struct{
    elements: ArrayList(anytype),

    pub fn new(elements: ArrayList(anytype)) Polynomial {
        return Polynomial{
            .elements: elements,
        }
    }

    pub fn isZero(self: Polynomial) bool {
        return self.degree() == 0;
    }

    pub fn degree(self: Polynomial) usize {
        var max_index: isize = -1;
        for (i, v) |0.., self| {
            if !v.isZero() {
                max_index = i;
            }
        }
        return i;
    }

    pub fn neg(self: Polynomial) Polynomial {
        var new_value = self;
        for (v) |&new_value| {
            v.negAssign();
        }

        return new_value;
    }

    pub fn negAssign(self: *Polynomial) void {
        for (v) |&self| {
            v.negAssign();
        }
    }

    inline fn addInner(value: *Polynomial, other: Polynomial) {
        const m = @max(value.elements.length(), other.elements.length());
        if m > value.elements.length() {
            value.elements.extend(m - value.elements.length());
        }

        for (i, v1, v2) |(0.., value.elements, other.elements)| {
            value[i] = v1.add(v2);
        }
    }

    pub fn add(self: Polynomial, other: Polynomial) Polynomial {
        var new_value = self;
        addInner(new_value, other);
        return new_value;
    }

    pub fn addInner(self: *Polynomial, other: Polynomial) void {
        addInner(self, other);
    }

    pub fn sub(self: Polynomial, other: Polynomial) Polynomial {
        const new_other = other.neg();
        addInner(new_value, new_other);
        return new_value;
    }

    pub fn subInner(self: *Polynomial, other: Polynomial) void {
        const new_other = other.neg();
        addInner(self, new_other);
    }

    inline fn mulInner(value: Polynomial, other: Polynomial, allocator: Allocator) Polynomial {
        const length = value.elements.length() + other.elements.length() - 1;
        var list = ArrayList(anytype).init(allocator);
        list.appendNTimes(anytype.new(0), length);
        var result = Polynomial{
            .elements: list,
        };

        for (i, v1) |0.., value.elements| {
            // sparse poly optimization
            if v1.isZero() {
                continue;
            }

            for (j, v2) |0.., other.elements| {
                result.elements[i+j].addAssign(v1.mul(v2));
            }
        }

        return result;
    }

    pub fn mul(self: Polynomial, other: Polynomial, allocator: Allocator) Polynomial {
        return mulInner(self, other);
    }

    pub fn mulAssign(self: *Polynomial, other: Polynomial, allocator: Allocator) Polynomial {
        self = mulInner(self, other);
    }

    inline fn divInner(numerator: Polynomial, denominator: Polynomial, allocator: Allocator) ?QuoRem {
        if denominator.degree() == -1 {
            return null;
        }
    
        if numerator.degree() < denominator.degree() {
            return QuoRem { .quotient: Polynomial.new(ArrayList(anytype).init(allocator)), .remainder: numerator};
        }

        var remainder = numerator;
        var q_list = ArrayList(anytype).init(allocator);
        const size = numerator.degree()-denominator.degree()+1;
        q_list.appendNTimes(anytype.new(0), size);
        var quotient = Polynomial.new(q_list);

        for (i) |0..size| {
            if remainder.degree() < denominator.degree() {
                break;
            }

            const coeff = remainder.leadingCoefficient().div(denominator.leadingCoefficient());
            const shift = remainder.degree() - denominator.degree();

            var sub_list = ArrayList(anytype).init(allocator);
            sub_list.appendNTimes(anytype.new(0), shift);
            sub_list.append(coeff);
            const sub = Polynomial.new(sub_list);
            defer sub.deinit();

            quotient.elements[shift] = coeff;
            remainder.subAssign(sub);
        }

        return QuoRem { .quotient: quotient, .remainder: remainder };
    }

    pub fn div(self: Polynomial, other: Polynomial) ?QuoRem {
        return divInner(self, other);
    }

    pub fn divAssign(self: *Polynomial, other: Polynomial) !void {
        const quorem = divInner(self, other) orelse return NoQuotientValue;
        self = quorem.quotient;
    }

    pub fn eval(self: Polynomial, point: anytype) anytype {
        var result = self.elements[0];
        const base_point = point;

        for (v) |self.elements| {
            result.addAssign(v.mul(point));
            point.mulAssign(base_point);
        }
    }

    // Simple iterative method
    // NOTE: should be updated to use FFT at some point
    pub fn interpolate(domain: &[anytype], values: &[anytype], allocator: Allocator) Polynomial {
        var x_list = ArrayList(anytype).init(allocator);
        x_list.push(anytype.new(0));
        x_list.push(anytype.new(1));
        const x = Polynomial.new(x_list);
        var acc = Polynomial.new(ArrayList(anytype).init(allocator));
        for (i, _) |0.., domain| {
            var product_list = ArrayList(anytype).init(allocator);
            product_list.push(values[i]);
            var product = Polynomial.new(product_list);

            for (j, _) |0.., domain| {
                if (j == i) {
                    continue;
                }


                var a_list = ArrayList(anytype).init(allocator);
                a_list.push(domain[j]);
                const a = Polynomial.new(a_list);

                var b_list = ArrayList(anytype).init(allocator);
                b_list.push(domain[i].sub(domain[j]));
                var b = Polynomial.new(b_list);
                b.negAssign();
                product.mulAssign(x.sub(a).mul(b));
            }

            acc.addAssign(product);
        }

        return acc;
    }

    pub fn leadingCoefficient(self: Polynomial) anytype {
        return self.elements[self.degree()];
    }

    pub fn deinit(self: Polynomial) void {
        self.elements.deinit();
    }
};

