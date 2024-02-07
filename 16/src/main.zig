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

const Dir = enum {
    Left,
    Right,
    Up,
    Down,
};

const SeenCell = std.EnumSet(Dir);

const Beam = struct {
    x: CoordInt,
    y: CoordInt,
    dir: Dir,
};

fn get_input_file() !std.fs.File {
    if (std.os.argv.len > 1) {
        return std.fs.cwd().openFile(std.mem.span(std.os.argv[1]), .{});
    }
    return std.io.getStdIn();
}

const Solver = struct {
    grid: GridView(u8),
    seen: GridView(SeenCell),
    beams: std.ArrayList(Beam),

    pub fn reset(self: *Solver) void {
        for (self.seen.data) |*s| {
            s.* = .{};
        }
        self.beams.clearRetainingCapacity();
    }

    pub fn show_seen(self: Solver, writer: anytype) !void {
        for (0..self.seen.h) |y| {
            for (0..self.seen.w) |x| {
                if (self.seen.at(x, y).bits.mask != 0) {
                    try writer.writeByte('#');
                } else {
                    try writer.writeByte('.');
                }
            }
            try writer.writeByte('\n');
        }
    }

    pub fn solve(self: *Solver) !u64 {
        while (self.beams.items.len != 0) {
            try self.advance_one_beam();
        }

        var count: u64 = 0;
        for (0..self.seen.h) |y| {
            for (0..self.seen.w) |x| {
                if (self.seen.at(x, y).bits.mask != 0) {
                    count += 1;
                }
            }
        }
        return count;
    }

    // assumes beams.items.len != 0
    fn advance_one_beam(self: *Solver) !void {
        const beam = self.beams.pop();
        if (self.seen.at(beam.x, beam.y).contains(beam.dir)) {
            // we've already been here
            return;
        }
        self.seen.ptrAt(beam.x, beam.y).insert(beam.dir);

        var new: Beam = undefined;
        var split_dir: ?Dir = null;
        const char = self.grid.at(beam.x, beam.y);
        new.dir = switch (char) {
            '.' => beam.dir, // continue in the same dir
            '/' => switch (beam.dir) {
                .Left => .Down,
                .Up => .Right,
                .Right => .Up,
                .Down => .Left,
            },
            '\\' => switch (beam.dir) {
                .Left => .Up,
                .Up => .Left,
                .Right => .Down,
                .Down => .Right,
            },
            '-' => switch (beam.dir) {
                .Left, .Right => beam.dir, // as if empty
                .Up, .Down => blk: {
                    split_dir = .Left;
                    // if the beam gets split, we explore the maximum
                    // amount of configurations: can apply this optimization
                    self.seen.setAt(beam.x, beam.y, SeenCell.initFull());
                    break :blk .Right;
                },
            },
            '|' => switch (beam.dir) {
                .Up, .Down => beam.dir, // as if empty
                .Left, .Right => blk: {
                    split_dir = .Up;
                    // if the beam gets split, we explore the maximum
                    // amount of configurations: can apply this optimization
                    self.seen.setAt(beam.x, beam.y, SeenCell.initFull());
                    break :blk .Down;
                },
            },
            else => std.debug.panic("Unexpected character in input: '{c}'", .{char}),
        };
        if (split_dir) |dir| split: {
            const x = switch (dir) {
                .Left => std.math.sub(CoordInt, beam.x, 1) catch break :split,
                .Right => beam.x + 1,
                .Up, .Down => beam.x,
            };
            const y = switch (dir) {
                .Up => std.math.sub(CoordInt, beam.y, 1) catch break :split,
                .Down => beam.y + 1,
                .Left, .Right => beam.y,
            };
            if (!self.grid.inBounds(x, y)) break :split;
            try self.beams.append(.{ .x = x, .y = y, .dir = dir });
        }

        new.x = switch (new.dir) {
            .Left => std.math.sub(CoordInt, beam.x, 1) catch return,
            .Right => beam.x + 1,
            .Up, .Down => beam.x,
        };
        new.y = switch (new.dir) {
            .Up => std.math.sub(CoordInt, beam.y, 1) catch return,
            .Down => beam.y + 1,
            .Left, .Right => beam.y,
        };
        if (!self.grid.inBounds(new.x, new.y)) return;

        try self.beams.append(new);
    }
};

pub fn main() !void {
    const pg_ally = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(pg_ally);
    // defer arena.deinit(); // don't care, OS will free it
    const ally = arena.allocator();

    const max_file_size = 1024 * 1024;

    const file = try get_input_file();
    const file_buf = try file.reader().readAllAlloc(ally, max_file_size);
    const w = std.mem.indexOfScalar(u8, file_buf, '\n') orelse return error.InvalidInput;

    // assume '\n' is a terminator
    const h = std.mem.count(u8, file_buf, "\n");
    std.debug.print("w={d} h={d} len={d}\n", .{ w, h, file_buf.len });
    const grid = GridView(u8){ .data = file_buf, .w = w, .h = h, .stride = w + 1 };

    const seen_buf = try ally.alloc(SeenCell, w * h);
    const seen = GridView(SeenCell){ .data = seen_buf, .w = w, .h = h, .stride = w };

    var beams = std.ArrayList(Beam).init(ally);

    var solver = Solver{ .grid = grid, .seen = seen, .beams = beams };
    solver.reset();
    try solver.beams.append(.{ .x = 0, .y = 0, .dir = .Right });

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const sol = try solver.solve();
    try stdout.print("Solution for part 1: {d}\n", .{sol});
    try bw.flush();

    var max_sol = sol;
    // left column
    for (1..h) |y| {
        solver.reset();
        solver.beams.appendAssumeCapacity(.{ .x = 0, .y = y, .dir = .Right });
        max_sol = @max(max_sol, try solver.solve());
    }
    // right column
    for (1..h) |y| {
        solver.reset();
        solver.beams.appendAssumeCapacity(.{ .x = w - 1, .y = y, .dir = .Left });
        max_sol = @max(max_sol, try solver.solve());
    }
    // top row
    for (1..w) |x| {
        solver.reset();
        solver.beams.appendAssumeCapacity(.{ .x = x, .y = 0, .dir = .Down });
        max_sol = @max(max_sol, try solver.solve());
    }
    // bottom row
    for (1..w) |x| {
        solver.reset();
        solver.beams.appendAssumeCapacity(.{ .x = x, .y = h - 1, .dir = .Up });
        max_sol = @max(max_sol, try solver.solve());
    }

    try stdout.print("Solution for part 2: {d}\n", .{max_sol});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
