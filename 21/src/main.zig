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

fn step(old: GridView(u8), new: GridView(u8)) void {
    for (0..old.h) |y| {
        for (0..old.w) |x| {
            switch (old.at(x, y)) {
                'O', 'S' => {
                    inline for (.{
                        .{ x, y -% 1 },
                        .{ x -% 1, y },
                        .{ x + 1, y },
                        .{ x, y + 1 },
                    }) |co| {
                        const newx = co[0];
                        const newy = co[1];
                        if (newx < new.w and newy < new.h) {
                            const n = new.ptrAt(newx, newy);
                            if (n.* == '.') n.* = 'O';
                        }
                    }
                },
                else => {},
            }
        }
    }
}

fn solve(ally: std.mem.Allocator, orig: GridView(u8)) !u32 {
    const sz = orig.h * orig.w;
    const buf = try ally.alloc(u8, sz * 3);
    defer ally.free(buf);

    var from = GridView(u8){
        .data = buf[0..sz],
        .w = orig.w,
        .h = orig.h,
        .stride = orig.w,
    };
    var to = from;
    to.data = buf[sz .. 2 * sz];
    var blank = from;
    blank.data = buf[2 * sz ..];
    for (0..orig.h) |y| {
        for (0..orig.w) |x| {
            from.setAt(x, y, orig.at(x, y));
            blank.setAt(x, y, switch (orig.at(x, y)) {
                'S' => '.',
                else => |c| c,
            });
        }
    }
    std.mem.copyForwards(u8, to.data, blank.data);

    for (0..64) |i| {
        step(from, to);
        _ = i;
        // debug
        // if (i < 3 or i > 62) {
        //     for (0..from.h) |y| {
        //         std.debug.print(
        //             "{s}    {s}\n",
        //             .{
        //                 from.data[from.stride * y ..][0..from.w],
        //                 to.data[to.stride * y ..][0..to.w],
        //             },
        //         );
        //     }
        //     std.debug.print("\n", .{});
        // }
        std.mem.copyForwards(u8, buf[0 .. 2 * sz], buf[sz..]);
    }

    var count: u32 = 0;
    for (from.data) |c| {
        if (c == 'O') count += 1;
    }
    return count;
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

    try stdout.print("Solution for part 1: {d}\n", .{sol});
    try bw.flush();
}
