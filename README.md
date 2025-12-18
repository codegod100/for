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
./scripts/run.sh -- <program args>
```

Any arguments passed after `--` are forwarded directly to `zig build run`, letting you pass program flags just as you would when invoking the executable manually.

If you prefer a manual invocation you can still rely on Zig directly:

```bash
zig build run -- <program args>
```

The compiled binary can also be executed from `zig-out/bin/remote-forward` once `zig build` (or the helper script) has completed.

## Run via `curl | bash`

To compile and run without cloning ahead of time, use the hosted script:

```bash
curl -sSf https://raw.githubusercontent.com/codegod100/for/main/scripts/remote-forward.sh | bash -s -- <program args>
```

The script clones the repository into a temporary directory, invokes `zig build run`, and forwards any arguments you pass after `--` to the executable. It requires both `git` and `zig` to already be available on your machine. You can pin to a different revision by setting `REMOTE_FORWARD_REF=<tag-or-branch>` before piping the script.
