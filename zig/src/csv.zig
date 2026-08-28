//! CSV output matching the project schema (nanoseconds, Language=zig).

const std = @import("std");

pub const Csv = struct {
    io: std.Io,
    file: std.Io.File,
    off: u64 = 0,

    pub fn create(io: std.Io, path: []const u8) !Csv {
        if (std.fs.path.dirname(path)) |dir| {
            std.Io.Dir.cwd().createDirPath(io, dir) catch {};
        }
        const file = try std.Io.Dir.cwd().createFile(io, path, .{});
        var self = Csv{ .io = io, .file = file };
        try self.writeRaw(
            "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,DataTypeInstanceCount,TypeConfigHash,RunOrder,SchedulePosition,SizeGzip,SizeZstd\n",
        );
        return self;
    }

    fn writeRaw(self: *Csv, bytes: []const u8) !void {
        try self.file.writePositionalAll(self.io, bytes, self.off);
        self.off += bytes.len;
    }

    pub fn deinit(self: *Csv) void {
        self.file.close(self.io);
    }

    pub fn writeRow(
        self: *Csv,
        mode: []const u8,
        test_data: []const u8,
        repetitions: u32,
        rep_index: u32,
        serializer: []const u8,
        version: []const u8,
        time_ser_ns: u64,
        time_deser_ns: u64,
        size: usize,
        fidelity: f64,
        native_kind: []const u8,
        stream_mode: []const u8,
        instance_count: i32,
        type_config_hash: []const u8,
        run_order: ?i32,
        schedule_position: ?i32,
        size_gzip: usize,
        size_zstd: usize,
    ) !void {
        const total = time_ser_ns + time_deser_ns;
        const ops_ser: f64 = if (time_ser_ns > 0) 1e9 / @as(f64, @floatFromInt(time_ser_ns)) else 0;
        const ops_deser: f64 = if (time_deser_ns > 0) 1e9 / @as(f64, @floatFromInt(time_deser_ns)) else 0;
        const ops_tot: f64 = if (total > 0) 1e9 / @as(f64, @floatFromInt(total)) else 0;
        var line_buf: [2048]u8 = undefined;
        const line = try std.fmt.bufPrint(&line_buf, "zig,{s},{s},{d},{d},{s},{s},{d},{d},{d},{d},{d:.6},{d:.6},{d:.6},0,{d:.1},{s},{s},{d},{s},", .{
            mode,
            test_data,
            repetitions,
            rep_index,
            serializer,
            version,
            time_ser_ns,
            time_deser_ns,
            size,
            total,
            ops_ser,
            ops_deser,
            ops_tot,
            fidelity,
            native_kind,
            stream_mode,
            instance_count,
            type_config_hash,
        });
        try self.writeRaw(line);
        if (run_order) |ro| {
            var tmp: [32]u8 = undefined;
            try self.writeRaw(try std.fmt.bufPrint(&tmp, "{d}", .{ro}));
        }
        try self.writeRaw(",");
        if (schedule_position) |sp| {
            var tmp: [32]u8 = undefined;
            try self.writeRaw(try std.fmt.bufPrint(&tmp, "{d}", .{sp}));
        }
        try self.writeRaw(",");
        if (size_gzip > 0) {
            var tmp: [32]u8 = undefined;
            try self.writeRaw(try std.fmt.bufPrint(&tmp, "{d}", .{size_gzip}));
        }
        try self.writeRaw(",");
        if (size_zstd > 0) {
            var tmp: [32]u8 = undefined;
            try self.writeRaw(try std.fmt.bufPrint(&tmp, "{d}", .{size_zstd}));
        }
        try self.writeRaw("\n");
    }
};

pub const Errors = struct {
    io: std.Io,
    file: ?std.Io.File = null,
    path: []const u8,
    off: u64 = 0,

    pub fn init(io: std.Io, path: []const u8) Errors {
        return .{ .io = io, .path = path };
    }

    pub fn deinit(self: *Errors) void {
        if (self.file) |f| f.close(self.io);
    }

    pub fn write(self: *Errors, type_id: []const u8, name: []const u8, mode: []const u8, rep: u32, text: []const u8) void {
        if (self.file == null) {
            const f = std.Io.Dir.cwd().createFile(self.io, self.path, .{}) catch return;
            self.file = f;
            const hdr = "TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n";
            f.writePositionalAll(self.io, hdr, 0) catch return;
            self.off = hdr.len;
        }
        var buf: [2048]u8 = undefined;
        const line = std.fmt.bufPrint(&buf, "{s},{s},{s},{d},{s}\n", .{
            type_id, name, mode, rep, text,
        }) catch return;
        if (self.file) |f| {
            f.writePositionalAll(self.io, line, self.off) catch return;
            self.off += line.len;
        }
    }
};
