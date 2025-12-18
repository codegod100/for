# remote-forward

Utility binary built with Zig. The executable is assembled through the `build.zig` script which produces the `remote-forward` binary under `zig-out/bin`.

## Requirements

- [Zig](https://ziglang.org/) 0.11.0 or newer available on your `PATH`.

## Building

```bash
./scripts/build.sh
```

The script wraps `zig build` so you can pass any additional Zig build options, for example `./scripts/build.sh -Drelease-safe=true`.

## Running

From the repository root, execute:

```bash
./scripts/run.sh -- user@ssh-bastion.example.com 443 8443
```

Arguments after `--` mirror the binary usage: first the SSH target, then the remote service port, and optionally a local port (defaults to the same number). In the example above, traffic from `localhost:8443` is tunneled over SSH to `user@ssh-bastion.example.com`, which forwards it to the remote host's port `443`. You can also prepend `--service-host my.internal.service` before the positional arguments to forward to a different host behind the SSH jump box.

If you prefer a manual invocation you can still rely on Zig directly:

```bash
zig build run -- <program args>
```

The compiled binary can also be executed from `zig-out/bin/remote-forward` once `zig build` (or the helper script) has completed.

## Run via `curl | bash`

To compile and run without cloning ahead of time, use the hosted script:

```bash
curl -sSf https://raw.githubusercontent.com/codegod100/for/main/scripts/remote-forward.sh | \
  bash -s -- user@ssh-bastion.example.com 443 8443
```

Just like the local helper script, the first argument is the SSH destination and the remaining values describe the remote and local ports that the tunnel should expose. The installer script clones this repository into a temporary directory, invokes `zig build run`, and forwards any extra flags (such as `--service-host api.internal`) directly to the executable. SSH is always used to carry the traffic to the remote port.
