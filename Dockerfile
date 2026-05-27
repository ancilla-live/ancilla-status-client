# syntax=docker/dockerfile:1.6
#
# Ancilla status client — container image.
#
# Two-stage build:
#   1. rust:alpine — compile the binary
#   2. alpine:3.20 — minimal runtime with TLS roots
#
# Final image: ~10 MB. Single static-ish binary at /usr/local/bin/ancilla.
# Multi-arch (amd64 + arm64) via buildx.
#

# === Stage 1: build ===
FROM --platform=$BUILDPLATFORM rust:1.85-alpine AS builder

RUN apk add --no-cache musl-dev openssl-dev openssl-libs-static pkgconfig

WORKDIR /build

# Copy manifest first so dependencies can cache when only sources change
COPY Cargo.toml Cargo.lock ./
COPY src ./src

# Static openssl for self-contained binary
ENV OPENSSL_STATIC=1

RUN cargo build --release --locked

# === Stage 2: runtime ===
FROM alpine:3.20

# CA roots so TLS verification works against ancilla.live
RUN apk add --no-cache ca-certificates && \
    update-ca-certificates

COPY --from=builder /build/target/release/ancilla /usr/local/bin/ancilla

# Run as non-root for safety
RUN adduser -D -u 1000 ancilla
USER ancilla

ENTRYPOINT ["/usr/local/bin/ancilla"]

# Metadata
LABEL org.opencontainers.image.title="ancilla"
LABEL org.opencontainers.image.description="Status client for the Ancilla platform. Fetches and renders the current project status from ancilla.live. Not the Ancilla platform itself."
LABEL org.opencontainers.image.url="https://ancilla.live"
LABEL org.opencontainers.image.source="https://github.com/ancilla-live/ancilla-status-client"
LABEL org.opencontainers.image.documentation="https://ancilla.live"
LABEL org.opencontainers.image.vendor="ancilla-live"
