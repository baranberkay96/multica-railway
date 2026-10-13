# Deploy and Host Multica with Railway

Multica is a source-available workspace where people and AI coding agents work from the same issue board. You assign an issue to an agent such as Claude Code or Codex the way you would assign a teammate, and every run, message and result is tracked on the issue. This community template deploys Multica v0.6.2 on Railway.

## About Hosting Multica

Multica has a Go backend (API, realtime and agent daemon hub), a Next.js web app and PostgreSQL. Agents run through the Multica CLI daemon, on your own computers or on Railway. This template uses the official `ghcr.io/multica-ai` images pinned to v0.6.2, with a small Caddy gateway that serves everything from one HTTPS domain and routes WebSockets straight to the backend, following upstream's single-origin layout. Postgres, Redis and a Railway Bucket stay on the private network. Sign-up is closed by default: only the email you enter at deploy time can create the first account.

## Common Use Cases

- Hand routine coding issues (bug fixes, tests, refactors, docs) to Claude Code or Codex agents and review their work on one board
- Run a shared board for a small engineering team where people and agents pick up issues side by side
- Keep issues, agent run history and attachments on infrastructure your organization controls
- Run agents 24/7 on Railway instead of a laptop, or connect your own machines as runtimes

## Dependencies for Multica Hosting

- PostgreSQL 17, Redis and a Railway Bucket (all included)
- An API key or subscription for at least one coding agent (Anthropic for Claude Code, OpenAI for Codex, or another agent supported by the Multica CLI)
- Optional: a Resend account to email sign-in codes and invitations

### Deployment Dependencies

- Multica repository and releases: https://github.com/multica-ai/multica
- Multica self-hosting guide: https://github.com/multica-ai/multica/blob/main/SELF_HOSTING.md
- Multica CLI and daemon guide: https://github.com/multica-ai/multica/blob/main/CLI_AND_DAEMON.md
- Resend (HTTP email API): https://resend.com/docs
- Railway Storage Buckets: https://docs.railway.com/storage-buckets

### Implementation Details

| Service | Image | Purpose |
|---|---|---|
| Gateway | `caddy:2.11.7-alpine` + Caddyfile | Only public domain. `/ws`, `/api/daemon/ws` and `/health` go to the backend, everything else to the web app |
| Multica Web | `ghcr.io/multica-ai/multica-web:v0.6.2` | Web app; forwards `/api`, `/auth`, `/v1` and `/uploads` to the backend |
| Multica Backend | `ghcr.io/multica-ai/multica-backend:v0.6.2` | API, realtime, daemon hub; migrations run as the pre-deploy step |
| Agent Runtime | `node:22` + Multica CLI, Claude Code, Codex | Optional agent runtime on Railway; idle until you add a token; volume at `/home/agent` |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl:17` | Primary database |
| Redis | `redis:8.2` | Auth rate limiting, realtime relay between replicas, caches |
| Bucket | Railway Storage Bucket | Attachments, avatars and uploads (served through the backend) |

**First login**

1. When deploying, enter your email in `ALLOWED_EMAILS`. Sign-up is restricted to that address (`ALLOW_SIGNUP=false`).
2. Open the Gateway's public URL, enter your email and request a code.
3. Without an email provider the code appears in the **Multica Backend** logs as `[DEV] Verification code for {your-email}: 123456`. Enter it and create your workspace.
4. Invite teammates from the workspace, or add their addresses or domains to `ALLOWED_EMAILS` / `ALLOWED_EMAIL_DOMAINS`. Set `DISABLE_WORKSPACE_CREATION=true` once your workspace exists if others should only join it.

**Email**: set `RESEND_API_KEY` and `RESEND_FROM_EMAIL` (an address on a domain verified in Resend) on Multica Backend so codes and invitations arrive by email. Resend uses HTTPS, so it works on every Railway plan. SMTP is also supported by Multica but outbound SMTP requires Railway Pro.

**Connecting agents**

- On Railway: in Multica open Settings, API Token, and create a token. Set it as `MULTICA_RUNTIME_TOKEN` on Agent Runtime together with `ANTHROPIC_API_KEY` and/or `OPENAI_API_KEY`, then deploy. The runtime appears under Settings, Runtimes. To use a Claude or ChatGPT subscription instead of an API key, open `railway ssh` on Agent Runtime and run `setpriv --reuid=agent --regid=agent --init-groups claude` (or `codex login --device-auth`); logins are kept on the volume.
- On your own computer: install the Multica CLI (`brew install multica-ai/tap/multica`), then run `multica setup self-host --server-url https://{your-domain} --app-url https://{your-domain}`.

**Scaling**: Multica Backend keeps no local state (files are in the Bucket, realtime events go through Redis), so you can raise its replicas; keep replicas × `DATABASE_MAX_CONNS` (20) below Postgres' 100 connections. Multica Web and Gateway can also scale. For more agent capacity raise Agent Runtime's RAM and `MULTICA_DAEMON_MAX_CONCURRENT_TASKS`, or duplicate the service.

**Custom domain**: attach it to the Gateway and set `FRONTEND_ORIGIN` on Multica Backend to `https://{your-domain}`; the related URLs follow automatically.

**Pinning and upgrades**: change `v0.6.2` on Multica Web and Multica Backend, and `MULTICA_VERSION` in the Agent Runtime Dockerfile, to the same newer release from the GitHub releases page. Back up Postgres first: migrations run automatically before the new backend starts and are forward-only.

**License**: Multica is distributed under the Multica License (Apache-2.0 with additional conditions). Self-hosting for internal use within your own organization is allowed. Offering Multica as a hosted or managed service to people outside your organization requires a commercial license from Index Labs, and the Multica logo, name and UI attribution must stay unchanged. This template runs the official images without modification. This is a community template, not affiliated with the Multica project.

### Why Deploy Multica on Railway?

Agents are only useful if the board, the backend and the runtimes stay online. Railway runs Multica's web app, backend, database, cache, file storage and an optional agent runtime together on a private network with HTTPS, logs and volumes, so your team can focus on assigning work to agents instead of running servers.
