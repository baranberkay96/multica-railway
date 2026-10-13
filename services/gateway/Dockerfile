# Single public entry point for Multica on Railway (Caddy reverse proxy).
# Routing is in the Caddyfile; upstreams come from MULTICA_WEB_UPSTREAM and
# MULTICA_BACKEND_UPSTREAM, the listen port from PORT.
FROM caddy:2.11.7-alpine

COPY Caddyfile /etc/caddy/Caddyfile

# The image's default command runs:
#   caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
