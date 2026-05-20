# Build stage: compile opencode binary using Bun
FROM oven/bun:1.3.14 AS builder

WORKDIR /build

# Build tools required for native addons (tree-sitter-powershell, node-pty, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git && \
    rm -rf /var/lib/apt/lists/*

COPY . .
RUN bun install --frozen-lockfile

WORKDIR /build/packages/opencode
RUN bun run script/build.ts --single --skip-embed-web-ui

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git curl ripgrep bash nodejs npm openssh-server procps && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/packages/opencode/dist/opencode-linux-x64/bin/opencode /usr/local/bin/opencode
RUN chmod +x /usr/local/bin/opencode

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /var/run/sshd /root/.ssh /workspace/.opencode && \
    chmod 700 /root/.ssh && \
    sed -i 's|#PermitRootLogin prohibit-password|PermitRootLogin yes|' /etc/ssh/sshd_config && \
    sed -i 's|#PasswordAuthentication yes|PasswordAuthentication yes|' /etc/ssh/sshd_config && \
    sed -i 's|UsePAM yes|UsePAM no|' /etc/ssh/sshd_config

WORKDIR /workspace

EXPOSE 22

CMD ["/entrypoint.sh"]
