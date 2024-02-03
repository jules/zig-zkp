const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Shake256 = std.crypto.sha3.Shake256;

const TranscriptError = error{
    TranscriptEmpty,
};

pub fn Transcript(comptime T: type) type {
    return struct {
        objects: ArrayList(T),
        read_index: u64,

        pub fn init(allocator: Allocator) Transcript(T) {
            return Transcript(T){
                .objects = ArrayList(T).init(allocator),
                .read_index = 0,
            };
        }

        pub fn push(self: *Transcript(T), obj: T) !void {
            return self.*.elements.append(obj);
        }

        pub fn pull(self: *Transcript(T)) !T {
            if (self.read_index == self.objects.items.len) {
                return TranscriptError.TranscriptEmpty;
            }

            const obj = self.objects.get(self.read_index).?;
            self.*.read_index = self.*.read_index + 1;
            return obj;
        }

        pub fn proverFiatShamir(self: Transcript(T), out: []u8, allocator: Allocator) void {
            var bytes = ArrayList(u8).init(allocator);
            defer bytes.deinit();
            for (self.objects.items) |obj| {
                const b = std.mem.asBytes(obj.value);
                bytes.extend(b);
            }

            Shake256.hash(bytes.items, out, struct {});
        }

        pub fn verifierFiatShamir(self: Transcript(T), out: []u8, allocator: Allocator) void {
            var bytes = ArrayList(u8).init(allocator);
            defer bytes.deinit();
            for (0.., self.objects.items) |i, obj| {
                if (i == self.read_index) {
                    break;
                }

                const b = std.mem.asBytes(obj.value);
                bytes.extend(b);
            }

            Shake256.hash(bytes.items, out, struct {});
        }

        pub fn deinit(self: Transcript(T)) void {
            self.objects.deinit();
        }
    };
}
