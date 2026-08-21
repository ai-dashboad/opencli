# opencli-core

This crate implements the business logic for OpenCLI. It is designed to be used by the various OpenCLI UIs written in Rust.

## Dependencies

Note that `opencli-core` makes some assumptions about certain helper utilities being available in the environment. Currently, this support matrix is:

### macOS

Expects `/usr/bin/sandbox-exec` to be present.

When using the workspace-write sandbox policy, the Seatbelt profile allows
writes under the configured writable roots while keeping `.git` (directory or
pointer file), the resolved `gitdir:` target, and `.opencli` read-only.

### Linux

Expects the binary containing `opencli-core` to run the equivalent of `opencli sandbox linux` (legacy alias: `opencli debug landlock`) when `arg0` is `opencli-linux-sandbox`. See the `opencli-arg0` crate for details.

### All Platforms

Expects the binary containing `opencli-core` to simulate the virtual `apply_patch` CLI when `arg1` is `--opencli-run-as-apply-patch`. See the `opencli-arg0` crate for details.
