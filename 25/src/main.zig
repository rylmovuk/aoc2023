const std = @import("std");
const Alloc = std.mem.Allocator;

const AdjMatrix = struct {
    data: std.DynamicBitSet,
    stride: u16 = 4096,

    const Self = @This();

    pub fn init(alloc: Alloc) Self {
        return .{ .data = .{ .allocator = alloc } };
    }

    pub fn deinit(self: *Self) void {
        self.data.deinit();
    }

    pub fn at(self: Self, a: u16, b: u16) bool {
        const idx = @as(usize, a) * self.stride + b;
        if (idx >= self.data.unmanaged.bit_length)
            return false;
        return self.data.isSet(idx);
    }

    pub fn setAt(self: *Self, a: u16, b: u16, v: bool) !void {
        if (a >= self.stride or b >= self.stride)
            @panic("whooops not implemented");
        const lim: usize = @max(a, b) + 1;
        if (self.data.unmanaged.bit_length <= lim * self.stride)
            try self.data.resize(lim * self.stride, false);
        self.data.setValue(@as(usize, a) * self.stride + b, v);
        self.data.setValue(@as(usize, b) * self.stride + a, v);
    }
};

const Solver = struct {
    const Tag = [3]u8;
    const TagMap = std.AutoHashMap(Tag, u16);

    adj_mat: AdjMatrix,
    str_to_idx: TagMap,
    idx_to_str: std.ArrayList(Tag),
    edge_list: std.ArrayList([2]u16),

    const Self = @This();

    pub fn initFromStr(ally: Alloc, input: []const u8) !Self {
        var lines_it = std.mem.tokenizeScalar(u8, input, '\n');
        var res: Self = .{
            .adj_mat = AdjMatrix.init(ally),
            .str_to_idx = TagMap.init(ally),
            .idx_to_str = std.ArrayList(Tag).init(ally),
            .edge_list = std.ArrayList([2]u16).init(ally),
        };
        errdefer res.adj_mat.deinit();
        errdefer res.str_to_idx.deinit();
        errdefer res.idx_to_str.deinit();
        while (lines_it.next()) |line| {
            const colon = 3;
            if (line[colon] != ':')
                return error.InvalidInput;
            const from_str = line[0..colon];
            const from = try res.registerNode(from_str.*);
            var it = std.mem.tokenizeScalar(u8, line[colon + 1 ..], ' ');
            while (it.next()) |to_str| {
                const to = try res.registerNode(to_str[0..3].*);
                if (!res.adj_mat.at(from, to)) {
                    try res.adj_mat.setAt(from, to, true);
                    try res.edge_list.append(.{ from, to });
                }
            }
        }
        return res;
    }

    fn registerNode(self: *Self, tag: Tag) !u16 {
        const gop = try self.str_to_idx.getOrPut(tag);
        if (!gop.found_existing) {
            const idx = self.idx_to_str.items.len;
            gop.value_ptr.* = @intCast(idx);
            try self.idx_to_str.append(tag);
        }
        return gop.value_ptr.*;
    }

    pub fn deinit(self: *Self) void {
        self.adj_mat.deinit();
        self.str_to_idx.deinit();
        self.idx_to_str.deinit();
        self.edge_list.deinit();
    }

    pub fn nodeCount(self: Self) usize {
        return self.idx_to_str.items.len;
    }

    fn connectedPart(self: Self) !u16 {
        const n = self.nodeCount();
        const ally = self.str_to_idx.allocator;
        var seen = try std.DynamicBitSet.initEmpty(ally, n);
        defer seen.deinit();
        var stk = std.ArrayList(u16).init(ally);
        defer stk.deinit();
        try stk.append(0);
        while (stk.popOrNull()) |cur| {
            const row_idx = @as(usize, cur) * (self.adj_mat.stride >> 6);
            const row: std.DynamicBitSetUnmanaged = .{
                .bit_length = n,
                .masks = self.adj_mat.data.unmanaged.masks + row_idx,
            };
            var it = row.iterator(.{});
            while (it.next()) |oth| {
                if (!seen.isSet(oth)) {
                    seen.set(oth);
                    try stk.append(@intCast(oth));
                }
            }
        }
        return @intCast(seen.count());
    }

    pub fn solve1(self: *Self) !u64 {
        for (self.edge_list.items, 0..) |edge1, i| {
            for (self.edge_list.items[i + 1 ..], i + 1..) |edge2, j| {
                std.debug.print("\r{} - {} - ...", .{ i, j });
                for (self.edge_list.items[j + 1 ..]) |edge3| {
                    try self.adj_mat.setAt(edge1[0], edge1[1], false);
                    try self.adj_mat.setAt(edge2[0], edge2[1], false);
                    try self.adj_mat.setAt(edge3[0], edge3[1], false);
                    defer self.adj_mat.setAt(edge1[0], edge1[1], true) catch unreachable;
                    defer self.adj_mat.setAt(edge2[0], edge2[1], true) catch unreachable;
                    defer self.adj_mat.setAt(edge3[0], edge3[1], true) catch unreachable;
                    const conn = try self.connectedPart();
                    if (conn != self.nodeCount()) {
                        return conn * (self.nodeCount() - conn);
                    }
                }
            }
        }
        return error.InvalidInput;
    }
};

fn getInputFile() !std.fs.File {
    if (std.os.argv.len > 1) {
        return std.fs.cwd().openFile(std.mem.span(std.os.argv[1]), .{});
    }
    return std.io.getStdIn();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const ally = gpa.allocator();

    const max_file_size = 1024 * 1024;

    const file = try getInputFile();
    const input = try file.reader().readAllAlloc(ally, max_file_size);
    defer ally.free(input);
    var solver = try Solver.initFromStr(ally, input);
    defer solver.deinit();
    std.debug.print("Solution for part 1: {}\n", .{try solver.solve1()});
    // std.debug.print("Solution for part 2: {}\n", .{try solver.solve2()});
}
