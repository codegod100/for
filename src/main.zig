const std = @import("std");

const PageAllocator = std.heap.page_allocator;
const ForwardConfig = struct {
    ssh_target: []const u8,
    remote_service_host: []const u8,
    remote_port: u16,
    local_port: u16,
};

pub fn main() !void {
    const allocator = PageAllocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const config = parseArgs(args);

    const local_addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, config.local_port);
    var server = try local_addr.listen(.{ .reuse_address = true });
    defer server.deinit();

    std.log.info(
        "forwarding 127.0.0.1:{d} -> {s}:{d} via ssh {s}",
        .{ config.local_port, config.remote_service_host, config.remote_port, config.ssh_target },
    );

    while (true) {
        var conn = server.accept() catch |err| {
            std.log.err("accept failed: {s}", .{@errorName(err)});
            continue;
        };

        const thread = std.Thread.spawn(.{}, handleClient, .{ conn, config }) catch |err| {
            std.log.err("failed to start worker thread: {s}", .{@errorName(err)});
            conn.stream.close();
            continue;
        };
        thread.detach();
    }
}

fn handleClient(conn: std.net.Server.Connection, config: ForwardConfig) void {
    var client_stream = conn.stream;
    const peer = conn.address;

    var peer_buf: [96]u8 = undefined;
    const peer_label = addrLabel(peer, peer_buf[0..]);
    std.log.info("client {s} connected", .{peer_label});
    defer {
        client_stream.close();
        std.log.info("client {s} closed", .{peer_label});
    }

    var ssh_child = spawnSsh(config.ssh_target, config.remote_service_host, config.remote_port) catch |err| {
        std.log.err("failed to start ssh tunnel: {s}", .{@errorName(err)});
        return;
    };
    var child_needs_cleanup = true;
    defer {
        if (child_needs_cleanup) forceKillChild(&ssh_child);
    }

    var remote_stdin = ssh_child.stdin orelse {
        std.log.err("ssh stdin unavailable", .{});
        return;
    };
    ssh_child.stdin = null;
    var remote_stdout = ssh_child.stdout orelse {
        remote_stdin.close();
        std.log.err("ssh stdout unavailable", .{});
        return;
    };
    ssh_child.stdout = null;

    const reverse_thread = std.Thread.spawn(.{}, remoteToClientThread, .{ remote_stdout, &client_stream, peer_label }) catch |err| {
        std.log.err("failed to start copy thread: {s}", .{@errorName(err)});
        remote_stdout.close();
        remote_stdin.close();
        return;
    };

    clientToRemote(&client_stream, &remote_stdin) catch |err| {
        std.log.warn("client->remote pipe stopped: {s}", .{@errorName(err)});
        shutdownBoth(&client_stream);
    };
    remote_stdin.close();

    reverse_thread.join();

    waitForChild(&ssh_child);
    child_needs_cleanup = false;
}

fn remoteToClientThread(remote_pipe: std.fs.File, client_stream: *std.net.Stream, peer_label: []const u8) void {
    var pipe_file = remote_pipe;
    defer pipe_file.close();

    var buffer: [16 * 1024]u8 = undefined;
    while (true) {
        const read_bytes = pipe_file.read(buffer[0..]) catch |err| {
            std.log.warn("remote->client read failed for {s}: {s}", .{ peer_label, @errorName(err) });
            shutdownBoth(client_stream);
            return;
        };
        if (read_bytes == 0) break;
        client_stream.writeAll(buffer[0..read_bytes]) catch |err| {
            std.log.warn("remote->client write failed for {s}: {s}", .{ peer_label, @errorName(err) });
            shutdownBoth(client_stream);
            return;
        };
    }

    shutdownWrite(client_stream);
}

fn clientToRemote(client_stream: *std.net.Stream, remote_stdin: *std.fs.File) !void {
    var buffer: [16 * 1024]u8 = undefined;
    while (true) {
        const read_bytes = try client_stream.read(buffer[0..]);
        if (read_bytes == 0) break;
        try remote_stdin.writeAll(buffer[0..read_bytes]);
    }
}

fn shutdownWrite(stream: *std.net.Stream) void {
    std.posix.shutdown(stream.handle, std.posix.ShutdownHow.send) catch {};
}

fn shutdownBoth(stream: *std.net.Stream) void {
    std.posix.shutdown(stream.handle, std.posix.ShutdownHow.both) catch {};
}

fn addrLabel(address: std.net.Address, buf: []u8) []const u8 {
    var writer: std.Io.Writer = .fixed(buf);
    address.format(&writer) catch {
        return "<addr>";
    };
    return std.Io.Writer.buffered(&writer);
}

fn usage() noreturn {
    std.debug.print("Usage: remote-forward [--service-host <host>] <ssh_target> <remote_port> [local_port]\n", .{});
    std.process.exit(1);
}

fn parsePort(port_text: []const u8) !u16 {
    return std.fmt.parseUnsigned(u16, port_text, 10);
}

fn argSlice(arg: [:0]u8) []const u8 {
    return std.mem.sliceTo(arg, 0);
}

fn parseArgs(args: []const [:0]u8) ForwardConfig {
    var idx: usize = 1;
    var remote_service_host_override: ?[]const u8 = null;

    while (idx < args.len and std.mem.startsWith(u8, argSlice(args[idx]), "--")) {
        const option = argSlice(args[idx]);
        if (std.mem.eql(u8, option, "--service-host")) {
            idx += 1;
            if (idx >= args.len) {
                std.log.err("--service-host requires a value", .{});
                usage();
            }
            remote_service_host_override = argSlice(args[idx]);
            idx += 1;
            continue;
        }

        std.log.err("unknown option: {s}", .{option});
        usage();
    }

    const remaining = args.len - idx;
    if (remaining < 2 or remaining > 3) {
        usage();
    }

    const ssh_target = argSlice(args[idx]);
    const remote_arg = argSlice(args[idx + 1]);
    const remote_port = parsePort(remote_arg) catch {
        std.log.err("invalid remote port: {s}", .{remote_arg});
        usage();
    };

    var local_port = remote_port;
    if (remaining == 3) {
        const local_arg = argSlice(args[idx + 2]);
        local_port = parsePort(local_arg) catch {
            std.log.err("invalid local port: {s}", .{local_arg});
            usage();
        };
    }

    const remote_service_host = remote_service_host_override orelse inferServiceHost(ssh_target);

    return .{
        .ssh_target = ssh_target,
        .remote_service_host = remote_service_host,
        .remote_port = remote_port,
        .local_port = local_port,
    };
}

fn inferServiceHost(ssh_target: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, ssh_target, '@')) |at| {
        if (at + 1 < ssh_target.len) {
            return ssh_target[at + 1 ..];
        }
    }
    return ssh_target;
}

fn spawnSsh(ssh_target: []const u8, service_host: []const u8, remote_port: u16) !std.process.Child {
    var dest_buf: [256]u8 = undefined;
    const destination = try std.fmt.bufPrint(&dest_buf, "{s}:{d}", .{ service_host, remote_port });

    var argv = [_][]const u8{
        "ssh",
        "-T",
        "-o",
        "ExitOnForwardFailure=yes",
        "-W",
        destination,
        ssh_target,
    };

    var child = std.process.Child.init(&argv, PageAllocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Inherit;
    try child.spawn();
    return child;
}

fn waitForChild(child: *std.process.Child) void {
    const term = child.wait() catch |err| {
        std.log.warn("ssh wait failed: {s}", .{@errorName(err)});
        return;
    };

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                std.log.warn("ssh exited with status {}", .{code});
            }
        },
        .Signal => |sig| std.log.warn("ssh terminated by signal {}", .{sig}),
        else => {},
    }
}

fn forceKillChild(child: *std.process.Child) void {
    if (child.stdin) |file| file.close();
    if (child.stdout) |file| file.close();
    if (child.stderr) |file| file.close();
    _ = child.kill() catch {};
    _ = child.wait() catch {};
}
