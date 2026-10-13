# NOTICE: Multica template

## Software deployed

| Component | Source | License | How it is used |
|---|---|---|---|
| Multica web app | https://github.com/multica-ai/multica, image `ghcr.io/multica-ai/multica-web:v0.6.2` | Multica License (Apache-2.0 with additional conditions), © 2025-2026 Index Labs (Hong Kong) Limited | Official image pulled unmodified. Logo, product name and UI attribution untouched. |
| Multica backend | same repository, image `ghcr.io/multica-ai/multica-backend:v0.6.2` | Multica License | Official image pulled unmodified (its `migrate` binary is used as the pre-deploy command). |
| Multica CLI / agent daemon | `multica` binary from `ghcr.io/multica-ai/multica-backend:v0.6.2` | Multica License | Copied unmodified into the Agent Runtime image together with upstream's `LICENSE` and `NOTICE` (installed under `/usr/share/doc/multica/`). |
| Claude Code | npm `@anthropic-ai/claude-code@2.1.296` | Anthropic's commercial terms | Installed unmodified in the Agent Runtime; use is subject to Anthropic's terms and the user's own account or API key. |
| Codex CLI | npm `@openai/codex@0.162.1` | Apache-2.0 (OpenAI) | Installed unmodified in the Agent Runtime; model use subject to OpenAI's terms. |
| Node.js base image | `node:22.23.3-bookworm-slim` | MIT (Node.js) plus Debian package licenses | Agent Runtime base image. |
| Caddy | `caddy:2.11.7-alpine` | Apache-2.0 | Gateway reverse proxy with a Caddyfile written for this template. |
| PostgreSQL | `ghcr.io/railwayapp-templates/postgres-ssl:17` (definition from `templates/_railway-base/postgres.json`, major set to 17) | PostgreSQL License | Railway's standard Postgres service. |
| Redis | `redis:8.2` (definition from `templates/_railway-base/redis.json`) | Redis Source Available License v2 / SSPL v1 / AGPLv3 (tri-licensed from Redis 8) | Railway's standard Redis service, used unmodified as a cache and relay. |
| Storage Bucket | Railway Storage Buckets | Railway service | Attachments and uploads via Multica's S3 storage. |

## Multica License conditions (summary, not legal advice)

The full text is the `LICENSE` file in the Multica repository (Part I additional conditions plus Part II, the Apache License 2.0). In short:

- **Internal use** within a single organization (including multiple workspaces) does not require a commercial license.
- **Hosted or embedded service for third parties**: offering Multica as SaaS, as a managed service, or as part of a commercial product to users outside your own organization requires a commercial license from Index Labs (Hong Kong) Limited (https://www.multica.ai/contact-sales), even when offered free of charge.
- **Branding**: the Multica logo, product name, and copyright and attribution information shown by a Multica user interface (including the `multica-web` image) must not be removed or modified without a written branding waiver.
- **Non-UI use** (backend, daemon or CLI without the Multica UI) must keep all notices and state in user-facing documentation that it is built on Multica, linking to https://github.com/multica-ai/multica.
- **Redistribution** of Multica or derivative works must include the complete Multica License file.

This template deploys the official images unmodified, changes no branding, and ships upstream's `LICENSE` and `NOTICE` inside the Agent Runtime image. Each person who deploys it operates their own instance and is responsible for staying within internal use or obtaining a commercial license. Seek legal advice if your use case is unclear.

Multica is a product of Index Labs (Hong Kong) Limited. This is a community template and is not affiliated with or endorsed by Index Labs or the Multica project.

## Upstream files checked (tag `v0.6.2`, released 2026-10-13, checked 2026-10-13)

- `LICENSE`, `NOTICE`
- `docker-compose.selfhost.yml` (services, environment, volumes), `Dockerfile`, `Dockerfile.web`, `docker/entrypoint.sh`
- `SELF_HOSTING.md`, `SELF_HOSTING_ADVANCED.md` (email, signup controls, S3, cookies, reverse proxy, health checks), `CLI_AND_DAEMON.md` (token login, daemon flags and environment)
- `apps/docs/content/docs/self-host-quickstart.mdx` (single-origin Caddy layout; "the web image cannot proxy WS upgrades"), `apps/docs/content/docs/auth-tokens.mdx`
- `apps/web/proxy.ts`, `apps/web/config/runtime-urls.ts`, `apps/web/next.config.ts` (runtime API proxying)
- `server/cmd/server/router.go` (routes, signup config, rate limiting, integration keys), `server/cmd/server/main.go`, `server/internal/handler/auth.go` (verification codes, signup checks), `server/internal/service/email.go`, `server/internal/storage/s3.go`, `server/internal/handler/file.go` (download modes), `server/internal/middleware/ratelimit.go`, `server/internal/util/secretbox/secretbox.go`, `server/internal/dbstartup/startup.go`, `server/internal/migrations/migrations.go`
- `server/cmd/multica/cmd_login.go`, `cmd_daemon.go`, `cmd_config.go`, `server/internal/daemon/config.go`, `server/pkg/agent/claude.go` (root restriction for bypass mode)
- `deploy/helm/multica/` (listing only)

Images verified with `docker buildx imagetools inspect` on 2026-10-13: `multica-backend:v0.6.2`, `multica-web:v0.6.2` (both with linux/amd64), `node:22.23.3-bookworm-slim`, `caddy:2.11.7-alpine`, `postgres-ssl:17`.

## Market templates and repositories reviewed (ideas only, nothing copied)

| Template / repo | License | Use |
|---|---|---|
| `multica` / `RockinPaul/multica_railway_template` | none (all rights reserved) | Read only for configuration ideas. No files or text copied. |
| `multica-prebuilt` (images `ghcr.io/hmseeb/multica-*`) | not stated | Reviewed for configuration choices; its patched images are not used. |
| `multica-ai` (official images on `latest`) | not stated | Reviewed for configuration choices. |

All files in this package (TEMPLATE.md, template.json, README.md, this NOTICE, `services/gateway/*`, `services/agent-runtime/*`) were written for this template.
