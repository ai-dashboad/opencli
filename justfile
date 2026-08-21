set working-directory := "opencli-rs"
set positional-arguments

# Display help
help:
    just -l

# `opencli`
alias c := opencli
opencli *args:
    cargo run --bin opencli -- "$@"

# `opencli exec`
exec *args:
    cargo run --bin opencli -- exec "$@"

# Run the CLI version of the file-search crate.
file-search *args:
    cargo run --bin opencli-file-search -- "$@"

# Build the CLI and run the app-server test client
app-server-test-client *args:
    cargo build -p opencli-cli
    cargo run -p opencli-app-server-test-client -- --opencli-bin ./target/debug/opencli "$@"

# format code
fmt:
    cargo fmt -- --config imports_granularity=Item 2>/dev/null

fix *args:
    cargo clippy --fix --all-features --tests --allow-dirty "$@"

clippy:
    cargo clippy --all-features --tests "$@"

install:
    rustup show active-toolchain
    cargo fetch

# Run `cargo nextest` since it's faster than `cargo test`, though including
# --no-fail-fast is important to ensure all tests are run.
#
# Run `cargo install cargo-nextest` if you don't have it installed.
test:
    cargo nextest run --no-fail-fast

# Build and run OpenCLI from source using Bazel.
# Note we have to use the combination of `[no-cd]` and `--run_under="cd $PWD &&"`
# to ensure that Bazel runs the command in the current working directory.
[no-cd]
bazel-opencli *args:
    bazel run //opencli-rs/cli:opencli --run_under="cd $PWD &&" -- "$@"

bazel-test:
    bazel test //... --keep_going

bazel-remote-test:
    bazel test //... --config=remote --platforms=//:rbe --keep_going

build-for-release:
    bazel build //opencli-rs/cli:release_binaries --config=remote

# Run the MCP server
mcp-server-run *args:
    cargo run -p opencli-mcp-server -- "$@"

# Regenerate the json schema for config.toml from the current config types.
write-config-schema:
    cargo run -p opencli-core --bin opencli-write-config-schema

# Regenerate vendored app-server protocol schema artifacts.
write-app-server-schema:
    cargo run -p opencli-app-server-protocol --bin write_schema_fixtures

# Tail logs from the state SQLite database
log *args:
    if [ "${1:-}" = "--" ]; then shift; fi; cargo run -p opencli-state --bin logs_client -- "$@"
