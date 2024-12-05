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
        const solv = Self{ .grid = try self.grid.clone(ally) };
        defer ally.free(solv.grid.data);
        // for (solv.grid.data) |*c| {
        //     switch (c.*) {
        //         '^', '>', 'v', '<' => c.* = '.',
        //         else => {},
        //     }
        // }
        const start_x = for (0..self.grid.w) |xi| {
            const x: CoordInt = @intCast(xi);
            if (self.grid.at(x, 0) == '.')
                break x;
        } else return error.InvalidInput;

        const Edge = struct {
            start: Coord2,
            end: Coord2,
            len: u16,
        };
        var edges = std.ArrayList(Edge).init(ally);
        defer edges.deinit();

        var stk = std.ArrayList(Edge).init(ally);
        defer stk.deinit();
        const start_co = .{ .x = start_x, .y = 0 };
        try stk.append(.{
            .start = start_co,
            .end = start_co,
            .len = 0,
        });

        while (stk.popOrNull()) |cur_edge| {
            var cur = cur_edge;
            if (!isEmpty(solv.grid.at(cur.end.x, cur.end.y)))
                continue;

            while (true) {
                solv.grid.setAt(cur.end.x, cur.end.y, 'O');
                const neigh = solv.emptyNeighbors(cur.end.x, cur.end.y).constSlice();
                if (neigh.len == 1) {
                    cur.end = neigh[0];
                    cur.len += 1;
                } else {
                    for (neigh) |n_co| {
                        try stk.append(.{ .start = cur.end, .end = n_co, .len = 1 });
                    }
                    break;
                }
            }

            {
                for (0..solv.grid.h) |y| {
                    for (0..solv.grid.w) |x| {
                        const char = solv.grid.at(@intCast(x), @intCast(y));
                        if (x == cur.start.x and y == cur.start.y) {
                            std.debug.print("\x1b[31mSS\x1b[0m", .{});
                        } else if (x == cur.end.x and y == cur.end.y) {
                            std.debug.print("\x1b[93mEE\x1b[0m", .{});
                        } else switch (char) {
                            '#' => std.debug.print("\x1b[90m##\x1b[0m", .{}),
                            else => std.debug.print("{0c}{0c}", .{char}),
                        }
                    }
                    std.debug.print("\n", .{});
                }
            }
            try std.io.getStdIn().reader().skipUntilDelimiterOrEof('\n');
            try edges.append(cur);
        }

        for (edges.items) |edge| {
            std.debug.print("({:>3},{:>3}) -- {:>3} --> ({:>3},{:>3})\n", .{ edge.start.x, edge.start.y, edge.len, edge.end.x, edge.end.y });
        }

        var nodes = std.AutoHashMap(Coord2, std.BoundedArray(struct { end: Coord2, len: u16 }, 4)).init(ally);
        defer nodes.deinit();
        for (edges.items) |edge| {
            const s_node = try nodes.getOrPutValue(edge.start, .{});
            s_node.value_ptr.appendAssumeCapacity(.{ .end = edge.end, .len = edge.len });
            const e_node = try nodes.getOrPutValue(edge.end, .{});
            e_node.value_ptr.appendAssumeCapacity(.{ .end = edge.start, .len = edge.len });
        }

        var seen = std.AutoHashMap(Coord2, void).init(ally);
        defer seen.deinit();

        var rec_stk = std.ArrayList(struct { node: Coord2, dist: u32 }).init(ally);
        defer rec_stk.deinit();
        try rec_stk.append(.{ .node = start_co, .dist = 0 });
        var max_dist: u32 = 0;

        while (rec_stk.getLastOrNull()) |entry| {
            if (entry.node.y == self.grid.h - 1) {
                std.debug.print("({},{})~~~ candidate {}\n", .{ entry.node.x, entry.node.y, entry.dist });
                max_dist = @max(max_dist, entry.dist);
                _ = rec_stk.pop();
            } else if (seen.get(entry.node) != null) {
                std.debug.print("(..) -> ", .{});
                _ = seen.remove(entry.node);
                _ = rec_stk.pop();
            } else {
                try seen.put(entry.node, {});
                std.debug.print("({},{})[{}]-> ", .{ entry.node.x, entry.node.y, entry.dist });
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
