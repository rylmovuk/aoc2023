const std = @import("std");

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

const Network = struct {
    const max_nodes = 1 << 7;
    const max_queue_size = 1 << 30;

    const button_id = 0;
    allocator: std.mem.Allocator,
    name_map: std.StringHashMapUnmanaged(Node.Id) = .{},
    rev_map: std.BoundedArray([]const u8, max_nodes) = .{},
    nodes: std.BoundedArray(Node, max_nodes) = .{},
    inputs_queue: BoundedQueue(Pulse, max_queue_size),
    low_count: u64 = 0,
    high_count: u64 = 0,

    pub const Pulse = struct { from: Node.Id, to: Node.Id, val: bool };

    pub fn initFromString(ally: std.mem.Allocator, input: []const u8) !Network {
        var net: Network = .{
            .allocator = ally,
            .inputs_queue = .{ .items = try ally.alloc(Pulse, max_queue_size) },
        };
        net.nodes.appendAssumeCapacity(.{ .kind = .broad });
        try net.name_map.put(ally, "<button>", button_id);
        net.rev_map.appendAssumeCapacity("<button>");
        // parse input string
        var lines_it = std.mem.tokenizeScalar(u8, input, '\n');
        while (lines_it.next()) |line| {
            var arrow_it = std.mem.splitSequence(u8, line, " -> ");
            const first = arrow_it.next() orelse return error.InvalidInput;
            const kind: Network.Node.Kind = switch (first[0]) {
                '%' => .flip,
                '&' => .conj,
                else => if (std.mem.eql(u8, first, "broadcaster"))
                    .broad
                else
                    .ignore,
            };
            const name = switch (kind) {
                .flip, .conj => first[1..],
                else => first,
            };

            const src_id = try net.getOrCreateNodeId(name);
            const src = net.getNode(src_id);
            src.setKind(kind);

            const second = arrow_it.next() orelse return error.InvalidInput;
            var out_it = std.mem.splitSequence(u8, second, ", ");
            while (out_it.next()) |out_name| {
                const out_id = try net.getOrCreateNodeId(out_name);
                try src.outputs.append(out_id);
            }
        }
        // fix rx!
        const rx_id = net.name_map.get("rx") orelse return error.InvalidInput;
        net.getNode(rx_id).setKind(.rx);
        // set up inputs maps for .conj nodes
        for (net.nodes.slice(), 0..) |node, node_id| {
            for (node.outputs.slice()) |out_id| {
                const out = net.getNode(out_id);
                if (out.kind == .conj) {
                    try out.state.conj_mem.append(.{
                        .id = @intCast(node_id),
                        .val = false,
                    });
                }
            }
        }
        // wire up button
        const broad_id = try net.getOrCreateNodeId("broadcaster");
        net.getNode(button_id).outputs.appendAssumeCapacity(broad_id);
        return net;
    }

    pub fn getOrCreateNodeId(self: *Network, name: []const u8) !Node.Id {
        const gop = try self.name_map.getOrPut(self.allocator, name);
        if (gop.found_existing) {
            return gop.value_ptr.*;
        }
        errdefer self.name_map.removeByPtr(gop.key_ptr);
        const id = @as(Node.Id, @intCast(self.nodes.len));
        try self.nodes.append(.{});
        errdefer {
            _ = self.nodes.pop();
        }
        try self.rev_map.append(name);
        gop.value_ptr.* = id;
        return id;
    }
    pub fn getNode(self: *Network, id: Node.Id) *Node {
        return &self.nodes.slice()[id];
    }
    fn debugShowPulse(self: *const Network, p: Pulse) void {
        const src = self.rev_map.get(p.from);
        const dst = self.rev_map.get(p.to);
        const sig = if (p.val) "hi" else "lo";
        std.debug.print("{s} --{s}-> {s}", .{ src, sig, dst });
    }
    pub fn sendToOutputs(self: *Network, src_id: Node.Id, val: bool) !void {
        const node = self.getNode(src_id);
        for (node.outputs.constSlice()) |out_id| {
            const pulse = Pulse{ .from = src_id, .to = out_id, .val = val };
            if (val) {
                self.high_count += 1;
            } else {
                self.low_count += 1;
            }
            try self.inputs_queue.enqueue(pulse);
        }
    }
    pub fn propagatePulses(self: *Network) !void {
        while (self.inputs_queue.dequeue()) |pulse| {
            // self.debugShowPulse(pulse);
            // std.debug.print("\n", .{});
            // std.io.getStdIn().reader().skipUntilDelimiterOrEof('\n') catch {};
            const recv_node = self.getNode(pulse.to);
            if (recv_node.process_one(pulse.from, pulse.val)) |result| {
                try self.sendToOutputs(pulse.to, result);
            }
        }
    }

    pub fn button(self: *Network) !void {
        try self.sendToOutputs(button_id, false);
    }

    pub fn deinit(self: *Network) void {
        self.name_map.deinit(self.allocator);
        self.allocator.free(self.inputs_queue.items);
    }

    pub fn dumpNode(self: *const Network, id: Node.Id, writer: anytype) !void {
        const node = self.nodes.get(id);
        const name = self.rev_map.slice()[id];
        switch (node.kind) {
            .flip => {
                try writer.writeByte('%');
            },
            .conj => {
                try writer.writeByte('&');
            },
            else => {},
        }
        try writer.writeAll(name);
        try writer.writeAll(" -> ");
        for (node.outputs.constSlice(), 0..) |out_id, i| {
            if (i != 0)
                try writer.writeAll(", ");
            const out_name = self.rev_map.slice()[out_id];
            try writer.writeAll(out_name);
        }
    }

    const Node = struct {
        const max_outputs = 8;
        const max_inputs = 16;
        pub const Id = std.math.IntFittingRange(0, max_nodes - 1);
        pub const Kind = enum { broad, flip, conj, rx, ignore };
        pub const RxCallback = struct {
            ctx: *anyopaque,
            cb: *const fn (*anyopaque) void,
        };

        kind: Kind = .ignore,
        outputs: std.BoundedArray(Id, max_outputs) = .{},
        state: union {
            none: void,
            conj_mem: std.BoundedArray(struct { id: Id, val: bool }, max_inputs),
            flip_state: bool,
            rx_callback: RxCallback,
        } = .{ .none = {} },

        pub fn setKind(self: *Node, kind: Kind) void {
            self.kind = kind;
            self.state = switch (kind) {
                .broad, .ignore => .{ .none = {} },
                .flip => .{ .flip_state = false },
                .conj => .{ .conj_mem = .{} },
                .rx => .{
                    .rx_callback = .{
                        .ctx = undefined,
                        .cb = struct {
                            pub fn F(c: *anyopaque) void {
                                _ = c;
                                unreachable;
                            }
                        }.F,
                    },
                },
            };
        }
        pub fn process_one(self: *Node, from: Id, val: bool) ?bool {
            switch (self.kind) {
                .broad => {
                    return val;
                },
                .flip => {
                    if (val) return null;
                    self.state.flip_state = !self.state.flip_state;
                    return self.state.flip_state;
                },
                .conj => {
                    for (self.state.conj_mem.slice()) |*mem| {
                        if (mem.id == from) {
                            mem.val = val;
                            break;
                        }
                    } else unreachable;
                    const all_high = for (self.state.conj_mem.constSlice()) |mem| {
                        if (!mem.val) break false;
                    } else true;
                    return !all_high;
                },
                .rx => {
                    if (!val)
                        self.state.rx_callback.cb(self.state.rx_callback.ctx);
                    return null;
                },
                .ignore => {
                    return null;
                },
            }
        }
    };
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
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const ally = arena.allocator();

    const file = try getInputFile();
    const max_file_size = 1024 * 1024;
    const input = try file.reader().readAllAlloc(ally, max_file_size);

    var net = try Network.initFromString(ally, input);

    // ------- naive approach -------
    //
    // // ~~ must remove `defers` above because this is a horrible hacky solution
    //
    // var presses: u64 = 0;
    // var saved_state = .{ .gpa = &gpa, .arena = &arena, .presses = &presses };
    // const aux = struct {
    //     fn finish(state: *@TypeOf(saved_state)) !void {
    //         defer state.arena.deinit();
    //         defer std.debug.assert(state.gpa.deinit() == .ok);
    //
    //         const stdout_file = std.io.getStdOut().writer();
    //         var bw = std.io.bufferedWriter(stdout_file);
    //         const stdout = bw.writer();
    //
    //         try stdout.print("Solution for part 2: {d}", .{state.presses.*});
    //         try bw.flush();
    //     }
    //     pub fn callback(ctx: *anyopaque) noreturn {
    //         const state = @as(*@TypeOf(saved_state), @alignCast(@ptrCast(ctx)));
    //         finish(state) catch |err| {
    //             std.log.err("{s}", .{@errorName(err)});
    //             if (@errorReturnTrace()) |trace| {
    //                 std.debug.dumpStackTrace(trace.*);
    //             }
    //             std.os.exit(1);
    //         };
    //
    //         std.os.exit(0);
    //     }
    // };

    // const rx_node = net.getNode(try net.getOrCreateNodeId("rx"));
    // rx_node.state.rx_callback = .{ .ctx = &saved_state, .cb = aux.callback };
    //
    // // const stderr = std.io.getStdErr();
    // var lim: u64 = 1 << 0;
    // while (true) {
    //     try net.button();
    //     presses += 1;
    //     if (presses == lim) {
    //         lim <<= 1;
    //         std.debug.print("{d} ... \n", .{presses});
    //         // stderr.flush() catch {};
    //     }
    //     try net.propagatePulses();
    // }

    // By visualizing the graph we discover that there are four tightly connected subgraphs
    // that each send *one* output to the conjunction node `&zr` that is right before the
    // output node `rx`.
    //
    // Thus we split the network into smaller ones and try to detect cyclic behavior.

    const input_names: [4][]const u8 = .{ "lq", "jn", "mn", "hd" };
    const output_names: [4][]const u8 = .{ "sz", "cm", "xf", "gc" };
    var presses: [4]u64 = .{0} ** 4;

    const btn_id = 0;
    const btn_node = net.getNode(btn_id);
    try btn_node.outputs.resize(1);

    for (input_names, output_names, &presses) |in_name, out_name, *prs| {
        const in_id = net.name_map.get(in_name) orelse return error.BadAssumptions;
        btn_node.outputs.set(0, in_id);

        const out_id = net.name_map.get(out_name) orelse return error.BadAssumptions;
        const out_node = net.getNode(out_id);
        out_node.setKind(.rx);

        var count: u64 = 0;
        var state = .{ .prs = prs, .cur = &count };

        const callback_fn = struct {
            fn FN(ctx: *anyopaque) void {
                const s: *@TypeOf(state) = @alignCast(@ptrCast(ctx));
                s.prs.* = s.cur.*;
            }
        }.FN;
        out_node.state.rx_callback = .{ .ctx = &state, .cb = callback_fn };

        while (prs.* == 0) {
            try net.button();
            count += 1;
            try net.propagatePulses();
        }
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var final_lcm: u64 = 1;
    for (presses) |p| {
        try stdout.print("presses: {d}\n", .{p});
        final_lcm = lcm(final_lcm, p);
    }
    try stdout.print("Solution for part 2: {d}\n", .{final_lcm});
    try bw.flush();
}

fn gcd(a_arg: u64, b_arg: u64) u64 {
    var a = a_arg;
    var b = b_arg;
    while (b != 0) {
        const t = b;
        b = a % b;
        a = t;
    }
    return a;
}

fn lcm(a: u64, b: u64) u64 {
    return a * (b / gcd(a, b));
}

test "parsing and dumping network is coherent" {
    const ally = std.testing.allocator;
    const StrSet = std.StringHashMap(void);

    const file = try std.fs.cwd().openFile("input", .{});
    const test_data = try file.reader().readAllAlloc(ally, 1024 * 1024);
    defer ally.free(test_data);
    var strs_arena = std.heap.ArenaAllocator.init(ally);
    defer strs_arena.deinit();
    const are_ally = strs_arena.allocator();
    var net = try Network.initFromString(ally, test_data);
    defer net.deinit();
    var node_reprs = StrSet.init(are_ally);
    for (1..net.nodes.len) |id| {
        var repr_buf = std.ArrayList(u8).init(are_ally);
        if (net.getNode(@intCast(id)).outputs.len == 0)
            continue;
        try net.dumpNode(@intCast(id), repr_buf.writer());
        try node_reprs.put(repr_buf.items, {});
    }

    // check
    var it = std.mem.tokenizeScalar(u8, test_data, '\n');
    var line_count: u32 = 0;
    while (it.next()) |line| {
        const get = node_reprs.getKeyPtr(line);
        if (get) |kptr| {
            node_reprs.removeByPtr(kptr);
        } else {
            std.debug.print("missing line: \"{s}\"\n", .{line});
            return error.TestMissingLine;
        }
        line_count += 1;
    }
    var kit = node_reprs.keyIterator();
    if (kit.next()) |line| {
        std.debug.print("extra line: \"{s}\"\n", .{line.*});
        return error.TestExtraLine;
    }
}

test "rx callback works" {
    const ally = std.testing.allocator;
    const test_data =
        \\%fx -> inv, aa
        \\%fy -> aa
        \\&inv -> fy
        \\&aa -> rx
        \\broadcaster -> fx
        \\
    ;

    var net = try Network.initFromString(ally, test_data);
    defer net.deinit();

    const rx_id = net.name_map.get("rx").?;
    const rx = net.getNode(rx_id);
    var reached: bool = false;
    const cb = struct {
        pub fn F(ctx: *anyopaque) void {
            const reached_ptr: *bool = @ptrCast(ctx);
            reached_ptr.* = true;
        }
    }.F;
    rx.state.rx_callback = .{ .ctx = @ptrCast(&reached), .cb = cb };
    try net.button();
    try net.propagatePulses();
    try std.testing.expect(reached);
}

test "part 1 is correct" {
    const ally = std.testing.allocator;

    const file = try std.fs.cwd().openFile("input", .{});
    const test_data = try file.reader().readAllAlloc(ally, 1024 * 1024);
    defer ally.free(test_data);

    var net = try Network.initFromString(ally, test_data);
    defer net.deinit();

    for (0..1000) |_| {
        try net.button();
        try net.propagatePulses();
    }
    try std.testing.expectEqual(@as(u64, 17664), net.low_count);
    try std.testing.expectEqual(@as(u64, 37986), net.high_count);
}
