const std = @import("std");

const CoordInt = usize;

fn GridView(comptime T: type) type {
    return struct {
        const Self = @This();
        data: []T,
        w: CoordInt,
        h: CoordInt,
        stride: CoordInt,

        pub fn inBounds(self: Self, x: CoordInt, y: CoordInt) bool {
            return x < self.w and y < self.h;
        }

        pub fn ptrAt(self: Self, x: CoordInt, y: CoordInt) *T {
            return &self.data[y * self.stride + x];
        }

        pub fn at(self: Self, x: CoordInt, y: CoordInt) T {
            return self.ptrAt(x, y).*;
        }

        pub fn setAt(self: Self, x: CoordInt, y: CoordInt, val: T) void {
            self.ptrAt(x, y).* = val;
        }
    };
}

fn BoundedQueue(comptime T: type, comptime buf_capacity: usize) type {
    return struct {
        const Self = @This();
        const Len = std.math.IntFittingRange(0, buf_capacity);

        items: []T,
        start: Len = 0,
        len: Len = 0,

        pub fn isEmpty(self: Self) bool {
            return self.len == 0;
        }

        pub fn enqueue(self: *Self, item: T) error{Overflow}!void {
            if (self.len == buf_capacity) return error.Overflow;
            self.enqueueAssumeCapacity(item);
        }
        pub fn enqueueAssumeCapacity(self: *Self, item: T) void {
            const idx = (self.start + self.len) % buf_capacity;
            self.items[idx] = item;
            self.len += 1;
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.len == 0) return null;
            const item = self.items[self.start];
            self.start += 1;
            self.start %= @intCast(buf_capacity);
            self.len -= 1;
            // if (len == 0) {
            //     self.* = .{};
            // }
            return item;
        }
    };
}

fn solve(ally: std.mem.Allocator, orig: GridView(u8)) !struct { part1: u64, part2: u64 } {
    const Entry = struct { dist: u8, x: u8, y: u8 };
    const que_size = 1 << 12;
    var que: BoundedQueue(Entry, que_size) = .{ .items = try ally.alloc(Entry, que_size) };
    defer ally.free(que.items);
    const initial_entry: Entry = outer: for (0..orig.h) |y| {
        for (0..orig.w) |x| {
            if (orig.at(x, y) == 'S')
                break :outer .{ .dist = 0, .x = @intCast(x), .y = @intCast(y) };
        }
    } else return error.BadInput;
    try que.enqueue(initial_entry);
    const visited: GridView(?u31) = .{
        .data = try ally.alloc(?u31, orig.w * orig.h),
        .w = orig.w,
        .h = orig.h,
        .stride = orig.w,
    };
    defer ally.free(visited.data);
    for (visited.data) |*elem| {
        elem.* = null;
    }
    while (que.dequeue()) |entry| {
        const x = entry.x;
        const y = entry.y;
        if (visited.at(x, y) != null)
            continue;

        visited.setAt(x, y, @intCast(entry.dist));

        inline for (.{
            .{ x, y -% 1 },
            .{ x -% 1, y },
            .{ x + 1, y },
            .{ x, y + 1 },
        }) |co| {
            const nx = co[0];
            const ny = co[1];
            if (orig.inBounds(nx, ny) and visited.at(nx, ny) == null and orig.at(nx, ny) != '#') {
                try que.enqueue(.{ .dist = entry.dist + 1, .x = nx, .y = ny });
            }
        }
    }
    for (0..visited.h) |y| {
        for (0..visited.w) |x| {
            if (visited.at(x, y)) |dist|
                std.debug.print("\x1b[90m{x:>2}\x1b[0m", .{dist})
            else
                std.debug.print("{0c}{0c}", .{orig.at(x, y)});
        }
        std.debug.print("\n", .{});
    }

    var part1: u64 = 0;
    var even_corners: u64 = 0;
    var odd_corners: u64 = 0;
    var even: u64 = 0;
    var odd: u64 = 0;
    for (visited.data) |maybe_dist| {
        const dist = maybe_dist orelse continue;
        const is_even = dist % 2 == 0;
        if (dist <= 64 and is_even)
            part1 += 1
        else if (dist > 65) {
            if (is_even)
                even_corners += 1
            else
                odd_corners += 1;
        }

        if (is_even)
            even += 1
        else
            odd += 1;
    }

    const n = @divFloor(26501365 - @divFloor(orig.h, 2), orig.h);
    std.debug.assert(n == 202300);

    const even_tiles = n * n;
    const odd_tiles = (n + 1) * (n + 1);

    const part2 = odd * odd_tiles + even * even_tiles - (n + 1) * odd_corners + n * even_corners;
    return .{ .part1 = part1, .part2 = part2 };
}

fn get_input_file() !std.fs.File {
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

    const file = try get_input_file();
    const file_buf = try file.reader().readAllAlloc(ally, max_file_size);
    defer ally.free(file_buf);
    const w = std.mem.indexOfScalar(u8, file_buf, '\n') orelse return error.InvalidInput;

    // assume '\n' is a terminator
    const h = std.mem.count(u8, file_buf, "\n");
    const grid = GridView(u8){ .data = file_buf, .w = w, .h = h, .stride = w + 1 };

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const sol = try solve(ally, grid);

    try stdout.print("Solution for part 1: {d}\n", .{sol.part1});
    try stdout.print("Solution for part 2: {d}\n", .{sol.part2});
    try bw.flush();
}
