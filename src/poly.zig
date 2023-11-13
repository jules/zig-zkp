/// Defines a polynomial with any kind of field element.
/// Makes no distinction between dense or sparse populations but tries to be as efficient
/// as possible despite this.
///
/// Coefficients are considered to be rising in degree.
pub const Polynomial = struct{
    elements: ArrayList(anytype),

    pub fn new(elements: ArrayList(anytype)) Polynomial {
        return Polynomial{
            .elements: elements,
        }
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

    inline fn mulInner(value: Polynomial, other: Polynomial) Polynomial {
        const length = value.elements.length() + other.elements.length() - 1;
        var result = Polynomial{
            .elements: ArrayList.with_length(length),
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

    pub fn mul(self: Polynomial, other: Polynomial) Polynomial {
        return mulInner(self, other);
    }

    pub fn mulAssign(self: *Polynomial, other: Polynomial) Polynomial {
        self = mulInner(self, other);

    }

    pub fn div(self: Polynomial, other: Polynomial) Polynomial {

    }

    pub fn divAssign(self: *Polynomial, other: Polynomial) Polynomial {

    }

    pub fn eval(self: Polynomial, point: anytype) anytype {
        var result = self.elements[0];
        const base_point = point;

        for (v) |self.elements| {
            result.addAssign(v.mul(point));
            point.mulAssign(base_point);
        }
    }
};

