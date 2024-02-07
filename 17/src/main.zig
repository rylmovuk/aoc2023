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

    fn opposite(d: Dir) Dir {
        return switch (d) {
            .Left => .Right,
            .Right => .Left,
            .Up => .Down,
            .Down => .Up,
        };
    }

    fn clockwise(d: Dir) Dir {
        return switch (d) {
            .Left => .Up,
            .Up => .Right,
            .Right => .Down,
            .Down => .Left,
        };
    }

    fn counterClockwise(d: Dir) Dir {
        return switch (d) {
            .Left => .Down,
            .Up => .Left,
            .Right => .Up,
            .Down => .Right,
        };
    }
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
    const Self = @This();
    const Node = struct {
        x: u32,
        y: u32,
        dir: Dir,
        steps: u8,
    };
    const Coords = struct {
        x: u32,
        y: u32,
    };
    const MinHeap = std.PriorityQueue(Node, *const Self, minHeapCompare);
    const Map = std.AutoHashMapUnmanaged(Node, u32);
    const infinity = std.math.maxInt(u32);

    grid: GridView(u8),
    open_set: MinHeap,
    // total_path_estimate[n]: current best guess for the length of path passing through n
    total_path_estimate: Map,
    // partial_path[n]: length of shortest path up to n
    partial_path: Map,
    comeFrom: std.AutoHashMapUnmanaged(Coords, Coords),

    fn minHeapCompare(ctx: *const Self, a: Node, b: Node) std.math.Order {
        return std.math.order(
            ctx.total_path_estimate.get(a) orelse infinity,
            ctx.total_path_estimate.get(b) orelse infinity,
        );
    }

    fn alloc(self: Self) std.mem.Allocator {
        // a little hack because there's no Unmanaged version of PriorityQueue
        return self.open_set.allocator;
    }

    fn heuristic(cell: Coords, goal: Coords) u32 {
        const dx = @as(i32, @intCast(goal.x)) - @as(i32, @intCast(cell.x));
        const dy = @as(i32, @intCast(goal.y)) - @as(i32, @intCast(cell.y));
        return @abs(dx) + @abs(dy);
    }

    fn stepInDir(self: Self, co: Coords, dir: Dir, steps: u32) ?Coords {
        var res = co;
        // overflow is somewhat of a hack, but works
        switch (dir) {
            .Left => {
                res.x -%= steps;
            },
            .Right => {
                res.x += steps;
            },
            .Up => {
                res.y -%= steps;
            },
            .Down => {
                res.y += steps;
            },
        }
        if (!self.grid.inBounds(res.x, res.y))
            return null;
        return res;
    }

    pub fn init(allocator: std.mem.Allocator, grid: GridView(u8)) Self {
        var res: Self = undefined;
        res = .{
            .grid = grid,
            .open_set = MinHeap.init(allocator, &res),
            .total_path_estimate = .{},
            .partial_path = .{},
            .comeFrom = .{},
        };
        return res;
    }

    pub fn getNeighborsNormal(self: *Self, cur: Node) std.BoundedArray(Node, 3) {
        var neighbors = std.BoundedArray(Node, 3){};
        const cur_co = .{ .x = cur.x, .y = cur.y };
        if (cur.steps < 3) {
            if (self.stepInDir(cur_co, cur.dir, 1)) |co| {
                neighbors.appendAssumeCapacity(.{
                    .x = co.x,
                    .y = co.y,
                    .dir = cur.dir,
                    .steps = cur.steps + 1,
                });
            }
        }
        const perp1 = cur.dir.clockwise();
        const perp2 = cur.dir.counterClockwise();
        if (self.stepInDir(cur_co, perp1, 1)) |co| {
            neighbors.appendAssumeCapacity(.{
                .x = co.x,
                .y = co.y,
                .dir = perp1,
                .steps = 1,
            });
        }
        if (self.stepInDir(cur_co, perp2, 1)) |co| {
            neighbors.appendAssumeCapacity(.{
                .x = co.x,
                .y = co.y,
                .dir = perp2,
                .steps = 1,
            });
        }
        return neighbors;
    }

    pub fn getNeighborsUltra(self: *Self, cur: Node) std.BoundedArray(Node, 3) {
        var neighbors = std.BoundedArray(Node, 3){};
        const cur_co = .{ .x = cur.x, .y = cur.y };
        if (cur.steps < 10) {
            if (self.stepInDir(cur_co, cur.dir, 1)) |co| {
                neighbors.appendAssumeCapacity(.{
                    .x = co.x,
                    .y = co.y,
                    .dir = cur.dir,
                    .steps = cur.steps + 1,
                });
            }
        }
        if (cur.steps >= 4) {
            const perp1 = cur.dir.clockwise();
            const perp2 = cur.dir.counterClockwise();
            if (self.stepInDir(cur_co, perp1, 1)) |co| {
                neighbors.appendAssumeCapacity(.{
                    .x = co.x,
                    .y = co.y,
                    .dir = perp1,
                    .steps = 1,
                });
            }
            if (self.stepInDir(cur_co, perp2, 1)) |co| {
                neighbors.appendAssumeCapacity(.{
                    .x = co.x,
                    .y = co.y,
                    .dir = perp2,
                    .steps = 1,
                });
            }
        }
        return neighbors;
    }

    pub fn findPath(self: *Self, start: Coords, goal: Coords, kind: enum { normal, ultra }) !u32 {
        self.reset();
        const start_node = Node{ .x = start.x, .y = start.y, .dir = .Right, .steps = 0 };
        try self.partial_path.put(self.alloc(), start_node, 0);
        try self.total_path_estimate.put(self.alloc(), start_node, heuristic(start, goal));
        try self.open_set.add(start_node);

        while (self.open_set.removeOrNull()) |cur| {
            if (cur.x == goal.x and cur.y == goal.y) {
                return self.partial_path.get(cur) orelse unreachable;
            }

            const neighbors = switch (kind) {
                .normal => self.getNeighborsNormal(cur),
                .ultra => self.getNeighborsUltra(cur),
            };

            for (neighbors.constSlice()) |nei| {
                const weight = try std.fmt.charToDigit(self.grid.at(nei.x, nei.y), 10);

                const nei_dist = if (self.partial_path.get(cur)) |dist|
                    dist + weight
                else
                    infinity;
                const best_dist_yet = self.partial_path.get(nei) orelse infinity;
                if (nei_dist < best_dist_yet) {
                    try self.partial_path.put(self.alloc(), nei, nei_dist);
                    try self.total_path_estimate.put(
                        self.alloc(),
                        nei,
                        nei_dist + heuristic(.{ .x = nei.x, .y = nei.y }, goal),
                    );
                    var it = self.open_set.iterator();
                    const present = while (it.next()) |node| {
                        if (std.meta.eql(node, nei))
                            break true;
                    } else false;
                    if (!present) {
                        try self.open_set.add(nei);
                    }
                }
            }
        }
        return error.Impossible;
    }

    pub fn reset(self: *Self) void {
        self.open_set.len = 0;
        self.total_path_estimate.clearRetainingCapacity();
        self.partial_path.clearRetainingCapacity();
        self.comeFrom.clearRetainingCapacity();
        self.open_set.context = self;
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

    var solver = Solver.init(ally, grid);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const sol = try solver.findPath(
        .{ .x = 0, .y = 0 },
        .{ .x = @intCast(w - 1), .y = @intCast(h - 1) },
        .normal,
    );
    try stdout.print("Solution for part 1: {d}\n", .{sol});
    try bw.flush();
    const sol2 = try solver.findPath(
        .{ .x = 0, .y = 0 },
        .{ .x = @intCast(w - 1), .y = @intCast(h - 1) },
        .ultra,
    );
    try stdout.print("Solution for part 2: {d}\n", .{sol2});
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
