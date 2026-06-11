# syntax=docker/dockerfile:1

# -----------------------------------------------------------------------------
# Stage 1: Build standalone luax binary (Rust + vendored LuaJIT via mlua)
# -----------------------------------------------------------------------------
FROM rust:1.78-bookworm AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libclang-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Lua transpiler sources (embedded by launcher/build.rs from parent directory)
COPY ast.lua lexer.lua parser.lua codegen.lua errors.lua transforms.lua ./
COPY src/transforms/ ./src/transforms/

# Rust launcher
COPY launcher/Cargo.toml launcher/build.rs ./launcher/
COPY launcher/src/ ./launcher/src/

WORKDIR /build/launcher
RUN cargo build --release

# -----------------------------------------------------------------------------
# Stage 2: Minimal runtime image
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /bin/bash luax

COPY --from=builder /build/launcher/target/release/luax /usr/local/bin/luax

WORKDIR /workspace
USER luax

ENTRYPOINT ["luax"]
CMD ["--help"]

# -----------------------------------------------------------------------------
# Stage 3: Dev image with Lua interpreter for running the Lua-based CLI/tests
# -----------------------------------------------------------------------------
FROM debian:bookworm-slim AS dev

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        lua5.1 \
        luajit \
        make \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/launcher/target/release/luax /usr/local/bin/luax
COPY ast.lua lexer.lua parser.lua codegen.lua errors.lua transforms.lua luax.lua luax ./
COPY src/ ./src/
COPY tests/ ./tests/
COPY examples/ ./examples/
COPY Makefile ./

WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "make test && luax --version"]
