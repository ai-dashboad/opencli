# Multi-stage Dockerfile for OpenCLI
# Builds both Rust CLI and Dart daemon in a single optimized image

# Stage 1: Build Rust CLI
FROM rust:1.75-alpine AS rust-builder

# Install build dependencies
RUN apk add --no-cache \
    musl-dev \
    openssl-dev \
    pkgconfig

WORKDIR /build

# Copy Rust project
COPY cli/ ./cli/

# Build CLI
WORKDIR /build/cli
RUN cargo build --release --target x86_64-unknown-linux-musl && \
    strip target/x86_64-unknown-linux-musl/release/opencli

# Stage 2: Build Dart daemon
FROM dart:stable AS dart-builder

WORKDIR /build

# Copy Dart project
COPY daemon/ ./daemon/

# Build daemon
WORKDIR /build/daemon
RUN dart pub get && \
    dart compile exe bin/daemon.dart -o opencli-daemon

# Stage 3: Runtime image
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    libgcc \
    libstdc++ \
    bash \
    curl \
    git

# Create non-root user
RUN addgroup -g 1000 opencli && \
    adduser -D -u 1000 -G opencli opencli

# Copy binaries from builders
COPY --from=rust-builder /build/cli/target/x86_64-unknown-linux-musl/release/opencli /usr/local/bin/opencli
COPY --from=dart-builder /build/daemon/opencli-daemon /usr/local/bin/opencli-daemon

# Set ownership
RUN chown opencli:opencli /usr/local/bin/opencli /usr/local/bin/opencli-daemon && \
    chmod +x /usr/local/bin/opencli /usr/local/bin/opencli-daemon

# Create directories
RUN mkdir -p /home/opencli/.opencli/config /home/opencli/.opencli/data && \
    chown -R opencli:opencli /home/opencli/.opencli

# Switch to non-root user
USER opencli
WORKDIR /home/opencli

# Set environment variables
ENV PATH="/usr/local/bin:${PATH}"
ENV OPENCLI_HOME="/home/opencli/.opencli"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD opencli status || exit 1

# Labels
ARG VERSION=dev
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="OpenCLI" \
      org.opencontainers.image.description="Universal AI Development Platform - Enterprise Autonomous Company Operating System" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.authors="OpenCLI Team" \
      org.opencontainers.image.url="https://opencli.ai" \
      org.opencontainers.image.source="https://github.com/opencli/opencli" \
      org.opencontainers.image.vendor="OpenCLI" \
      org.opencontainers.image.licenses="MIT"

# Default command
CMD ["opencli", "--help"]
