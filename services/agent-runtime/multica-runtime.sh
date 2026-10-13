#!/bin/sh
# Entrypoint of the Multica agent runtime on Railway.
#
# Runs as root only long enough to hand the volume to the `agent` user, then
# drops privileges with setpriv (which keeps the working directory and the
# environment). Claude Code refuses its autonomous permission mode as root, so
# the daemon and every agent it spawns run as `agent`.
#
# Without MULTICA_RUNTIME_TOKEN the service stays idle and prints how to
# connect it. With a token it waits for the backend, logs the CLI in and runs
# `multica daemon start --foreground` as the main process.
set -eu

AGENT_USER="agent"
AGENT_HOME="${HOME:-/home/agent}"

log() {
  printf '[multica-runtime] %s\n' "$*"
}

as_agent() {
  setpriv --reuid="$AGENT_USER" --regid="$AGENT_USER" --init-groups "$@"
}

# Railway mounts volumes owned by root. Only the top level needs fixing: every
# file below it is created by the agent user.
mkdir -p "$AGENT_HOME"
chown "$AGENT_USER:$AGENT_USER" "$AGENT_HOME"

token="${MULTICA_RUNTIME_TOKEN:-}"
# Keep the token out of the daemon's environment (agents inherit it).
unset MULTICA_RUNTIME_TOKEN

if [ -z "$token" ]; then
  log "Idle: MULTICA_RUNTIME_TOKEN is not set, so no agents run on Railway yet."
  log "To connect this runtime:"
  log "  1. Sign in to Multica and create your workspace."
  log "  2. Open Settings > API Tokens and create a personal access token (mul_...)."
  log "  3. Set it as MULTICA_RUNTIME_TOKEN on this service, plus ANTHROPIC_API_KEY"
  log "     and/or OPENAI_API_KEY (or log the CLIs in over Railway SSH), then deploy."
  exec setpriv --reuid="$AGENT_USER" --regid="$AGENT_USER" --init-groups sleep infinity
fi

server_url="${MULTICA_SERVER_URL:?MULTICA_SERVER_URL must point at the Multica backend}"
server_url="${server_url%/}"
app_url="${MULTICA_APP_URL:-}"
wait_seconds="${MULTICA_RUNTIME_WAIT_SECONDS:-900}"

# Services start in parallel on Railway; the backend may still be migrating.
waited=0
until curl -fsS -o /dev/null --max-time 5 "$server_url/health"; do
  if [ "$waited" -ge "$wait_seconds" ]; then
    log "Backend not reachable at $server_url after ${wait_seconds}s; exiting so Railway restarts the service."
    exit 1
  fi
  log "Waiting for the Multica backend at $server_url ..."
  sleep 5
  waited=$((waited + 5))
done

as_agent multica config set server_url "$server_url" >/dev/null
if [ -n "$app_url" ]; then
  as_agent multica config set app_url "${app_url%/}" >/dev/null
fi

log "Logging the Multica CLI in with the configured token."
if ! as_agent multica login --token "$token"; then
  log "Login failed. Check MULTICA_RUNTIME_TOKEN (it must be a personal access token, mul_...)."
  exit 1
fi
unset token

# Pin the daemon to the image's CLI version: no GitHub self-update, no binary
# reload. Upgrades happen by redeploying a newer image.
log "Starting the Multica daemon."
exec setpriv --reuid="$AGENT_USER" --regid="$AGENT_USER" --init-groups \
  multica daemon start --foreground --no-auto-update --no-auto-reload
