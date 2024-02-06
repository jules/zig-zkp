const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Blake2b = std.crypto.blake2.Blake2b256;

const MerkleTreeError = error{
    LengthNotPowerOfTwo,
    IndexOutOfBounds,
};

pub fn commit(leaves: anytype, out: *[32]u8, allocator: Allocator) void {
    var hashes = ArrayList([32]u8).init(allocator);
    defer hashes.deinit();
    for (leaves) |obj| {
        const b = std.mem.asBytes(obj.value);
        const digest: [32]u8 = undefined;
        Blake2b.hash(b, &digest, struct {});
        hashes.append(digest) catch unreachable;
    }

    commit_internal(hashes.toOwnedSlice() catch unreachable, out, allocator);
}

fn commit_internal(hashes: [][32]u8, out: *[32]u8, allocator: Allocator) void {
    while (hashes.len % 2 != 0 and hashes.len != 1) {
        hashes.append([_]u8{0} ** 32) catch unreachable;
    }

    while (hashes.items.len != 1) {
        hashes = hash_layer(hashes, allocator);
        defer hashes.deinit();
    }

    out = hashes.get(0).?; // XXX: will this disappear due to deinit
}

fn hash_layer(hashes: [][32]u8, allocator: Allocator) ArrayList([32]u8) {
    var new_hashes = ArrayList([32]u8).init(allocator);
    var index: usize = 0;
    while (index < hashes.len) {
        const input = hashes[index] ++ hashes[index + 1];
        const digest: [32]u8 = undefined;
        Blake2b.hash(input, &digest, struct {});
        new_hashes.append(digest) catch unreachable;
        index = index + 2;
    }

    return new_hashes;
}

pub fn open(index: usize, leaves: anytype, out: *[32]u8, allocator: Allocator) !void {
    if (leaves.len & (leaves.len - 1) != 0) {
        return MerkleTreeError.LengthNotPowerOfTwo;
    }

    if (index >= leaves.len) {
        return MerkleTreeError.IndexOutOfBounds;
    }

    var hashes = ArrayList([32]u8).init(allocator);
    defer hashes.deinit();
    for (leaves) |obj| {
        const b = std.mem.asBytes(obj.value);
        const digest: [32]u8 = undefined;
        Blake2b.hash(b, &digest, struct {});
        hashes.append(digest) catch unreachable;
    }

    while (hashes.items.len == 2) {
        const len_hashes_over_two = hashes.items.len / 2;
        var commit_out: [32]u8 = undefined;
        if (index < (len_hashes_over_two)) {
            commit_internal(hashes.items[len_hashes_over_two .. hashes.len - 1], &commit_out, allocator);
            var hashes_slice = hashes.toOwnedSlice() catch unreachable;
            hashes_slice = hashes_slice[0..len_hashes_over_two] ++ commit_out;
            hashes = ArrayList([32]u8).fromOwnedSlice(allocator, hashes_slice);
        } else {
            index = index - len_hashes_over_two;
            commit_internal(hashes.items[0..len_hashes_over_two], &commit_out, allocator);
            var hashes_slice = hashes.toOwnedSlice() catch unreachable;
            hashes_slice = hashes_slice[len_hashes_over_two .. hashes.len - 1] ++ commit_out;
            hashes = ArrayList([32]u8).fromOwnedSlice(allocator, hashes_slice);
        }
    }

    out.* = hashes.get(1 - index).?;
}

pub fn verify(root: [32]u8, index: usize, path: [][32]u8, leaf: anytype) !bool {
    if (index >= (1 << path.len)) {
        return MerkleTreeError.IndexOutOfBounds;
    }

    const b = std.mem.asBytes(leaf.value);
    var leaf_hash: [32]u8 = undefined;
    Blake2b.hash(b, &leaf_hash, struct {});

    while (path.len > 1) {
        const input = undefined;
        if (index % 2 == 0) {
            input = leaf_hash ++ path[0];
        } else {
            input = path[0] ++ leaf_hash;
        }

        Blake2b.hash(input, &leaf_hash, struct {});
        index = index >> 1;
        path = path[1 .. path.len - 1];
    }

    if (index == 0) {
        const input = leaf_hash ++ path[0];
        const digest: [32]u8 = undefined;
        Blake2b.hash(input, &digest, struct {});
        return root == digest;
    } else {
        const input = path[0] ++ leaf_hash;
        const digest: [32]u8 = undefined;
        Blake2b.hash(input, &digest, struct {});
        return root == digest;
    }
}
