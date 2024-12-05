const std = @import("std");

fn get_input_file() !std.fs.File {
    if (std.os.argv.len > 1) {
        return std.fs.cwd().openFile(std.mem.span(std.os.argv[1]), .{});
    }
    return std.io.getStdIn();
}

const Solver = struct {
    seq: []const u8,
    counts: []const u8,
    alloc: std.mem.Allocator,

    state: struct {
        memo: MemoMap = .{},

        const MemoMap = std.AutoHashMapUnmanaged(struct { seq_i: usize, counts_i: usize }, u64);
    } = .{},

    pub fn init(alloc: std.mem.Allocator, seq: []const u8, counts: []const u8) Solver {
        return .{
            .seq = seq,
            .counts = counts,
            .alloc = alloc,
        };
    }

    pub fn resetState(self: *Solver) void {
        self.state.memo.deinit(self.alloc);
        self.state = .{};
    }

    pub fn solve(self: *Solver) !u64 {
        self.resetState();
        return self.solveMemo(0, 0);
    }

    fn solveMemo(self: *Solver, seq_i: usize, counts_i: usize) !u64 {
        const key = .{
            .seq_i = seq_i,
            .counts_i = counts_i,
        };
        // std.debug.print("{any}", .{key});
        if (self.state.memo.get(key)) |found_val| {
            return found_val;
        }
        const computed_val = try self.solveRec(seq_i, counts_i);
        try self.state.memo.put(self.alloc, key, computed_val);
        return computed_val;
    }

    fn solveRec(self: *Solver, seq_i: usize, counts_i: usize) error{OutOfMemory}!u64 {
        var si = seq_i;

        while (si < self.seq.len and self.seq[si] == '.')
            si += 1;

        if (si >= self.seq.len) {
            const no_runs_expected = counts_i == self.counts.len;
            return if (no_runs_expected) 1 else 0;
        }

        if (counts_i == self.counts.len) {
            const no_runs_present = std.mem.indexOfScalarPos(u8, self.seq, si, '#') == null;
            return if (no_runs_present) 1 else 0;
        }
        const sum = b: {
            var s: u32 = 0;
            for (self.counts[counts_i..]) |c|
                s += c;
            break :b s;
        };
        // even if all are '?', there's no way to get to the target sum
        // (for 2, 3, 1 we must have 2+3+1 = 6 chars, plus len-1 = 3-1 = 2
        // to have at least one '.' of spacing
        if (self.seq.len - si < (sum + self.counts.len - counts_i - 1)) {
            return 0;
        }

        var res: u64 = 0;
        const cur_count = self.counts[counts_i];

        if (self.seq[si] == '?') {
            // We may try setting this '?' to '.'
            res += try self.solveMemo(si + 1, counts_i);
        }

        const group_ok =
            for (self.seq[si..][0..cur_count]) |c|
        {
            if (c == '.')
                break false;
        } else true;

        const sep_ok = si + cur_count == self.seq.len or self.seq[si + cur_count] != '#';

        if (group_ok and sep_ok) {
            // We may try setting the block at `si` of length `cur_count` to all '#'s
            // and the following character to '.'
            res += try self.solveMemo(si + cur_count + 1, counts_i + 1);
        }
        return res;
    }
};

pub fn main() !void {
    const pg_ally = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(pg_ally);
    // defer arena.deinit(); // don't care, OS will free it
    const ally = arena.allocator();

    const max_file_size = 1024 * 1024;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var sum: u64 = 0;

    const file = try get_input_file();
    const file_buf = try file.reader().readAllAlloc(ally, max_file_size);
    var lines = std.mem.splitScalar(u8, file_buf, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, ' ');
        const seq_short = parts.first();
        const seq = try std.mem.join(ally, "?", &([_][]const u8{seq_short} ** 5));
        const counts_str = parts.rest();
        var counts: std.BoundedArray(u8, 32) = .{};
        var it = std.mem.splitScalar(u8, counts_str, ',');
        while (it.next()) |num| {
            try counts.append(try std.fmt.parseInt(u8, num, 10));
        }
        const orig_len = counts.len;
        for (0..4) |_| {
            try counts.appendSlice(counts.slice()[0..orig_len]);
        }

        // std.debug.print("{s} {any}\n", .{ seq, counts.slice() });

        var solver = Solver.init(ally, seq, counts.slice());

        const solution = try solver.solve();

        sum += solution;
    }

    try stdout.print("Solution: {}\n", .{sum});

    try bw.flush(); // don't forget to flush!
}
