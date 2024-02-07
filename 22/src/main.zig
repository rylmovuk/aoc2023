const std = @import("std");
const Allocator = std.mem.Allocator;

const Vec3 = struct { x: u16, y: u16, z: u16 };

const Block = struct {
    lo: Vec3,
    hi: Vec3,
};

const Grid = struct {
    const Self = @This();
    extents: Vec3,
    data: []u16,

    pub fn initZero(alloc: Allocator, extents: Vec3) !Grid {
        const res = .{
            .extents = extents,
            .data = try alloc.alloc(u16, extents.x * extents.y * extents.z),
        };
        @memset(res.data, 0);
        return res;
    }

    pub fn clone(self: Self, alloc: Allocator) !Self {
        return .{ .extents = self.extents, .data = try alloc.dupe(u16, self.data) };
    }

    pub fn deinit(self: *Self, alloc: Allocator) void {
        alloc.free(self.data);
        self.data = &.{};
    }

    pub fn inBounds(self: Self, x: u16, y: u16, z: u16) bool {
        return x < self.extents.x and y < self.extents.y and z < self.extents.z;
    }
    pub fn inBoundsCo(self: Self, co: Vec3) bool {
        return self.inBounds(co.x, co.y, co.z);
    }

    pub fn at(self: Self, x: u16, y: u16, z: u16) *u16 {
        return &self.data[z * self.extents.y * self.extents.x + y * self.extents.x + x];
    }
    pub fn atCo(self: Self, co: Vec3) *u16 {
        return self.at(co.x, co.y, co.z);
    }
};

const Solver = struct {
    blocks: []Block,
    grid: Grid,

    const Self = @This();

    pub fn initFromStr(alloc: Allocator, input: []const u8) !Solver {
        var blocks = std.ArrayList(Block).init(alloc);
        errdefer blocks.deinit();
        var it = std.mem.tokenizeScalar(u8, input, '\n');
        var ext = Vec3{ .x = 0, .y = 0, .z = 0 };
        while (it.next()) |line| {
            const block = try parseInputLine(line);
            try blocks.append(block);
            ext.x = @max(ext.x, block.hi.x + 1);
            ext.y = @max(ext.y, block.hi.y + 1);
            ext.z = @max(ext.z, block.hi.z + 1);
        }
        var res = Self{
            .blocks = try blocks.toOwnedSlice(),
            .grid = try Grid.initZero(alloc, ext),
        };
        errdefer res.grid.deinit(alloc);
        for (0.., res.blocks) |i, block| {
            res.fillBlock(block, @intCast(i + 1));
        }
        return res;
    }
    pub fn deinit(self: *Self, alloc: Allocator) void {
        alloc.free(self.blocks);
        self.grid.deinit(alloc);
    }

    pub fn clone(self: Self, alloc: Allocator) !Self {
        return .{
            .blocks = try alloc.dupe(Block, self.blocks),
            .grid = try self.grid.clone(alloc),
        };
    }

    pub fn settle(self: Self) u16 {
        const ext = self.grid.extents;
        var moved_count: u16 = 0;
        for (1..ext.z) |z| {
            for (0..ext.x) |x| {
                for (0..ext.y) |y| {
                    const cell = self.grid.at(@intCast(x), @intCast(y), @intCast(z)).*;
                    if (cell != 0) {
                        const block = &self.blocks[cell - 1];
                        self.fillBlock(block.*, 0);
                        const b_new = self.dropBlock(block.*);
                        if (!std.meta.eql(block.*, b_new))
                            moved_count += 1;
                        block.* = b_new;
                        self.fillBlock(block.*, cell);
                    }
                }
            }
        }
        return moved_count;
    }

    pub fn solve1(self: *Self, alloc: Allocator) !u32 {
        var count: u32 = 0;

        _ = self.settle();
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        var are_ally = arena.allocator();
        for (self.blocks, 0..) |block, i| {
            std.debug.print("\r{}/{}...   ", .{ i, self.blocks.len });
            const other = try self.clone(are_ally);
            other.fillBlock(block, 0);
            if (other.settle() == 0) {
                count += 1;
            }
            _ = arena.reset(.retain_capacity);
        }
        std.debug.print("\n", .{});
        return count;
    }

    pub fn solve2(self: *Self, alloc: Allocator) !u32 {
        var count: u32 = 0;

        _ = self.settle();
        var arena = std.heap.ArenaAllocator.init(alloc);
        defer arena.deinit();
        var are_ally = arena.allocator();
        for (self.blocks, 0..) |block, i| {
            std.debug.print("\r{}/{}...   ", .{ i, self.blocks.len });
            const other = try self.clone(are_ally);
            other.fillBlock(block, 0);
            count += other.settle();
            _ = arena.reset(.retain_capacity);
        }
        std.debug.print("\n", .{});
        return count;
    }

    fn dropBlock(self: Self, b: Block) Block {
        var bn = b;
        while (bn.lo.z > 0) {
            bn.lo.z -= 1;
            bn.hi.z -= 1;
            if (!self.isFree(bn)) {
                bn.lo.z += 1;
                bn.hi.z += 1;
                break;
            }
        }
        return bn;
    }

    fn isFree(self: Self, b: Block) bool {
        for (b.lo.x..b.hi.x + 1) |x|
            for (b.lo.y..b.hi.y + 1) |y|
                for (b.lo.z..b.hi.z + 1) |z|
                    if (self.grid.at(@intCast(x), @intCast(y), @intCast(z)).* != 0)
                        return false;
        return true;
    }

    fn fillBlock(self: Self, b: Block, val: u16) void {
        for (b.lo.x..b.hi.x + 1) |x|
            for (b.lo.y..b.hi.y + 1) |y|
                for (b.lo.z..b.hi.z + 1) |z| {
                    self.grid.at(@intCast(x), @intCast(y), @intCast(z)).* = val;
                };
    }

    fn nextNumber(it: *std.mem.SplitIterator(u8, .any)) !u16 {
        return std.fmt.parseUnsigned(u16, it.next() orelse return error.InvalidInput, 10);
    }

    fn parseInputLine(line: []const u8) !Block {
        var it = std.mem.splitAny(u8, line, ",~");
        var x1 = try nextNumber(&it);
        var y1 = try nextNumber(&it);
        var z1 = try nextNumber(&it);
        var x2 = try nextNumber(&it);
        var y2 = try nextNumber(&it);
        var z2 = try nextNumber(&it);
        if (x1 > x2) std.mem.swap(u16, &x1, &x2);
        if (y1 > y2) std.mem.swap(u16, &y1, &y2);
        if (z1 > z2) std.mem.swap(u16, &z1, &z2);
        return .{ .lo = .{ .x = x1, .y = y1, .z = z1 }, .hi = .{ .x = x2, .y = y2, .z = z2 } };
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

    var solver = blk: {
        const file = try getInputFile();
        const input = try file.reader().readAllAlloc(ally, max_file_size);
        defer ally.free(input);
        break :blk try Solver.initFromStr(ally, input);
    };
    defer solver.deinit(ally);
    std.debug.print("Solution for part 1: {}\n", .{try solver.solve1(ally)});
    std.debug.print("Solution for part 2: {}\n", .{try solver.solve2(ally)});
}
