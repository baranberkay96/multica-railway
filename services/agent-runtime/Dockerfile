# Multica agent runtime for Railway.
#
# Runs the official `multica` CLI daemon (taken unmodified from the official
# backend image of the same release) next to Claude Code and Codex, as a
# non-root user whose home directory is the Railway volume. The daemon connects
# to the Multica backend over Railway's private network, registers the agent
# CLIs it finds as runtimes, and executes the issues assigned to them.
#
# Upgrade: keep MULTICA_VERSION equal to the backend/web image tag.

ARG MULTICA_VERSION=v0.6.2

FROM ghcr.io/multica-ai/multica-backend:${MULTICA_VERSION} AS multica

FROM node:22.23.3-bookworm-slim

# PIN_ prefix: build args are environment variables during RUN, and Claude Code
# reads CLAUDE_CODE_* variables itself.
ARG PIN_CLAUDE_CODE_VERSION=2.1.296
ARG PIN_CODEX_VERSION=0.162.1

# git/openssh for repository checkouts, curl for the backend wait loop,
# ripgrep for the agents' code search, setpriv (util-linux) for dropping root.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git openssh-client ripgrep procps util-linux \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --no-fund --no-audit \
       "@anthropic-ai/claude-code@${PIN_CLAUDE_CODE_VERSION}" \
       "@openai/codex@${PIN_CODEX_VERSION}" \
    && npm cache clean --force

COPY --from=multica /app/multica /usr/local/bin/multica
# Ship Multica's license and attribution notices with the image (Multica
# License, condition 1c and 3d).
COPY --from=multica /app/LICENSE /app/NOTICE /usr/share/doc/multica/

RUN groupadd --gid 1001 agent \
    && useradd --uid 1001 --gid agent --home-dir /home/agent --shell /bin/bash agent \
    && mkdir -p /home/agent \
    && chown agent:agent /home/agent

COPY multica-runtime.sh /usr/local/bin/multica-runtime
RUN chmod 0755 /usr/local/bin/multica-runtime

# DISABLE_AUTOUPDATER stops Claude Code from updating itself at runtime; the
# versions above are the ones that run.
ENV HOME=/home/agent \
    MULTICA_WORKSPACES_ROOT=/home/agent/multica_workspaces \
    DISABLE_AUTOUPDATER=1

# Fail the build early if any tool the entrypoint or the daemon needs is missing.
RUN cd /tmp && HOME=/tmp setpriv --version \
    && HOME=/tmp multica version \
    && HOME=/tmp claude --version \
    && HOME=/tmp codex --version \
    && git --version \
    && rm -rf /tmp/.claude* /tmp/.codex /tmp/.multica

WORKDIR /home/agent

ENTRYPOINT ["/usr/local/bin/multica-runtime"]
