const std = @import("std");
const Alloc = std.mem.Allocator;

const CoordInt = u16;

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

        pub fn clone(self: Self, ally: Alloc) !Self {
            return .{
                .data = try ally.dupe(T, self.data),
                .w = self.w,
                .h = self.h,
                .stride = self.stride,
            };
        }
    };
}

const Coord2 = struct { x: CoordInt, y: CoordInt };

const Solver = struct {
    grid: GridView(u8),

    const Self = @This();

    pub fn initFromStr(input: []u8) !Self {
        const w = std.mem.indexOfScalar(u8, input, '\n') orelse return error.InvalidInput;
        const stride = w + 1;
        const h = std.math.divExact(usize, input.len, stride) catch return error.InvalidInput;
        return .{
            .grid = .{ .data = input, .w = @intCast(w), .h = @intCast(h), .stride = @intCast(stride) },
        };
    }

    fn isEmpty(char: u8) bool {
        return switch (char) {
            '.', '<', '>', '^', 'v' => true,
            else => false,
        };
    }

    fn emptyNeighbors(self: Self, x: CoordInt, y: CoordInt) std.BoundedArray(Coord2, 4) {
        var res = std.BoundedArray(Coord2, 4){};
        if (x > 0 and isEmpty(self.grid.at(x - 1, y))) {
            res.appendAssumeCapacity(.{ .x = x - 1, .y = y });
        }
        if (y > 0 and isEmpty(self.grid.at(x, y - 1))) {
            res.appendAssumeCapacity(.{ .x = x, .y = y - 1 });
        }
        if (x + 1 < self.grid.w and isEmpty(self.grid.at(x + 1, y))) {
            res.appendAssumeCapacity(.{ .x = x + 1, .y = y });
        }
        if (y + 1 < self.grid.h and isEmpty(self.grid.at(x, y + 1))) {
            res.appendAssumeCapacity(.{ .x = x, .y = y + 1 });
        }
        return res;
    }

    fn neighbors(self: Self, x: CoordInt, y: CoordInt) std.BoundedArray(Coord2, 4) {
        var res = std.BoundedArray(Coord2, 4){};
        if (x > 0) {
            res.appendAssumeCapacity(.{ .x = x - 1, .y = y });
        }
        if (y > 0) {
            res.appendAssumeCapacity(.{ .x = x, .y = y - 1 });
        }
        if (x + 1 < self.grid.w) {
            res.appendAssumeCapacity(.{ .x = x + 1, .y = y });
        }
        if (y + 1 < self.grid.h) {
            res.appendAssumeCapacity(.{ .x = x, .y = y + 1 });
        }
        return res;
    }

    fn followCorridor(self: Self, co_a: Coord2, start_co: Coord2) struct { last: Coord2, end: Coord2, len: u16 } {
        var co = co_a;
        var last_co = start_co;
        var len: u16 = 1;
        while (true) {
            const neigh = self.emptyNeighbors(co.x, co.y).slice();
            if (neigh.len != 2) {
                break;
            }
            const t = if (std.meta.eql(neigh[0], last_co)) neigh[1] else neigh[0];
            last_co = co;
            co = t;
            len += 1;
        }
        return .{ .last = last_co, .end = co, .len = len };
    }

    pub fn solve1(self: Self, ally: Alloc) !u32 {
        const start_x = for (0..self.grid.w) |xi| {
            const x: u16 = @intCast(xi);
            if (self.grid.at(x, 0) == '.')
                break x;
        } else return error.InvalidInput;

        var max_length: u32 = 0;
        const State = struct {
            length: u32,
            pos: Coord2,
            solv: Solver,
        };
        var stack = std.ArrayList(State).init(ally);
        defer stack.deinit();
        try stack.append(.{
            .length = 0,
            .pos = .{ .x = start_x, .y = 0 },
            .solv = .{ .grid = try self.grid.clone(ally) },
        });

        while (stack.items.len != 0) {
            const cur = &stack.items[stack.items.len - 1];
            const ch = cur.solv.grid.at(cur.pos.x, cur.pos.y);
            switch (ch) {
                '^', '>', 'v', '<' => {
                    cur.length += 1;
                    cur.solv.grid.setAt(cur.pos.x, cur.pos.y, 'O');
                    switch (ch) {
                        '^' => cur.pos.y -= 1,
                        '>' => cur.pos.x += 1,
                        'v' => cur.pos.y += 1,
                        '<' => cur.pos.x -= 1,
                        else => unreachable,
                    }
                    continue;
                },
                '#', 'O' => {
                    // std.debug.print("{s}\n", .{cur.solv.grid.data});
                    ally.free(cur.solv.grid.data);
                    _ = stack.pop();
                    continue;
                },
                else => {},
            }
            const neigh = cur.solv.emptyNeighbors(cur.pos.x, cur.pos.y).constSlice();
            if (neigh.len == 0) {
                if (cur.pos.y == self.grid.h - 1) {
                    max_length = @max(max_length, cur.length);
                }
                // std.debug.print("{s}\n", .{cur.solv.grid.data});
                ally.free(cur.solv.grid.data);
                _ = stack.pop();
            } else {
                cur.solv.grid.setAt(cur.pos.x, cur.pos.y, 'O');
                cur.length += 1;
                cur.pos = neigh[0];
                for (neigh[1..]) |npos| {
                    try stack.append(.{
                        .length = cur.length,
                        .pos = npos,
                        .solv = .{ .grid = try cur.solv.grid.clone(ally) },
                    });
                }
            }
        }

        return max_length;
    }

    fn solve2(self: Self, ally: Alloc) !u32 {
        const start_x = for (0..self.grid.w) |xi| {
            const x: CoordInt = @intCast(xi);
            if (self.grid.at(x, 0) == '.')
                break x;
        } else return error.InvalidInput;

        const start_co = .{ .x = start_x, .y = 0 };

        var nodes = std.AutoHashMap(Coord2, std.BoundedArray(struct { end: Coord2, len: u16 }, 4)).init(ally);
        defer nodes.deinit();

        // find all *nodes*: either dead ends (1 neighbor) or forks (>2 neighbors).
        // corridors (=2 neighbors) can be compressed
        for (0..self.grid.h) |y_usz| {
            for (0..self.grid.w) |x_usz| {
                const x: CoordInt = @intCast(x_usz);
                const y: CoordInt = @intCast(y_usz);
                if (isEmpty(self.grid.at(x, y))) {
                    const neigh = self.emptyNeighbors(x, y).constSlice();
                    if (neigh.len != 2) {
                        try nodes.put(.{ .x = x, .y = y }, .{});
                    }
                }
            }
        }

        // connect the nodes together. note that we basically treat this as a directed graph,
        // i.e. every edge is duplicated (once as A->B and once as B->A)
        var node_it = nodes.iterator();
        while (node_it.next()) |node_entry| {
            const node = node_entry.key_ptr.*;
            const node_edges = node_entry.value_ptr;
            const neigh = self.emptyNeighbors(node.x, node.y).slice();
            for (neigh) |n_co| {
                const follow = self.followCorridor(n_co, node);
                try node_edges.append(.{ .end = follow.end, .len = follow.len });
                std.debug.print("x{:0>3}y{:0>3} -- x{:0>3}y{:0>3} [weight={}]\n", .{ node.x, node.y, follow.end.x, follow.end.y, follow.len });
            }
        }

        var seen = std.AutoHashMap(Coord2, void).init(ally);
        defer seen.deinit();

        var rec_stk = std.ArrayList(struct { node: Coord2, dist: u32 }).init(ally);
        defer rec_stk.deinit();
        try rec_stk.append(.{ .node = start_co, .dist = 0 });
        var max_dist: u32 = 0;

        while (rec_stk.getLastOrNull()) |entry| {
            if (entry.node.y == self.grid.h - 1) {
                // std.debug.print("({},{})~~~ candidate {}\n", .{ entry.node.x, entry.node.y, entry.dist });
                max_dist = @max(max_dist, entry.dist);
                _ = rec_stk.pop();
            } else if (seen.get(entry.node) != null) {
                // std.debug.print("(..) -> ", .{});
                _ = seen.remove(entry.node);
                _ = rec_stk.pop();
            } else {
                try seen.put(entry.node, {});
                // std.debug.print("({},{})[{}]-> ", .{ entry.node.x, entry.node.y, entry.dist });
                const adj_edges = nodes.get(entry.node).?;
                for (adj_edges.slice()) |e| {
                    const neigh = e.end;
                    if (seen.get(neigh) == null)
                        try rec_stk.append(.{ .node = neigh, .dist = entry.dist + e.len });
                }
            }
        }

        return max_dist;
    }

    fn debugShow(self: Self, start: Coord2, end: Coord2) void {
        for (0..self.grid.h) |y| {
            for (0..self.grid.w) |x| {
                const char = self.grid.at(@intCast(x), @intCast(y));
                if (x == start.x and y == start.y) {
                    std.debug.print("\x1b[31mSS\x1b[0m", .{});
                } else if (x == end.x and y == end.y) {
                    std.debug.print("\x1b[93mEE\x1b[0m", .{});
                } else switch (char) {
                    '#' => std.debug.print("\x1b[90m##\x1b[0m", .{}),
                    else => std.debug.print("{0c}{0c}", .{char}),
                }
            }
            std.debug.print("\n", .{});
        }
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
    const solver = try Solver.initFromStr(input);
    std.debug.print("Solution for part 1: {}\n", .{try solver.solve1(ally)});
    std.debug.print("Solution for part 2: {}\n", .{try solver.solve2(ally)});
}
