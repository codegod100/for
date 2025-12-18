# remote-forward

Utility binary built with Zig. The executable is assembled through the `build.zig` script which produces the `remote-forward` binary under `zig-out/bin`.

## Quick start (`curl | bash`)

To run the prebuilt binary without cloning or compiling, pipe the hosted script directly to Bash:

```bash
curl -sSf https://raw.githubusercontent.com/codegod100/for/main/scripts/remote-forward.sh | \
  bash -s -- user@ssh-bastion.example.com 443 8443
```

The script downloads the latest CI-built binary artifact (via [nightly.link](https://nightly.link/)), extracts it, and executes it with the arguments you pass after `--`. Only `curl` and `unzip` are required on your machine. Set `REMOTE_FORWARD_BIN_URL=<custom zip url>` if you want to pin a specific artifact or mirror. SSH still transports all forwarded traffic.

> **Note:** The hosted artifact targets Linux on x86_64 using baseline CPU features, so it should run on most modern Linux servers. For other operating systems or architectures, clone the repo and build locally as described below.

## Running from a local checkout

From the repository root, execute:

```bash
./scripts/run.sh -- user@ssh-bastion.example.com 443 8443
```

Arguments after `--` mirror the binary usage: first the SSH target, then the remote service port, and optionally a local port (defaults to the same number). In the example above, traffic from `localhost:8443` is tunneled over SSH to `user@ssh-bastion.example.com`, which forwards it to the remote host's port `443`. By default the remote host equals the hostname portion of the SSH destination (e.g., `ssh-bastion.example.com`); prepend `--service-host my.internal.service` before the positional arguments to forward to a different host behind the SSH jump box.

If you prefer a manual invocation you can still rely on Zig directly:

```bash
zig build run -- <program args>
```

The compiled binary can also be executed from `zig-out/bin/remote-forward` once `zig build` (or the helper script) has completed.

## Requirements (local builds)

- [Zig](https://ziglang.org/) 0.15.2 or newer available on your `PATH` if you plan to build locally.

## Building

```bash
./scripts/build.sh
```

The script wraps `zig build` so you can pass any additional Zig build options, for example `./scripts/build.sh -Drelease-safe=true`.
