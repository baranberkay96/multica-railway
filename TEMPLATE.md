# Multica v0.6 AI Agent Team Workspace: Railway template spec

## Listing

| Field | Value |
|---|---|
| Name | **Multica v0.6 AI Agent Team Workspace** (36 chars; `v0.6` = major.minor of the pinned `v0.6.2`, per the 0.x naming rule) |
| Description | Assign issues to coding agents like teammates and track every run. (66 chars) |
| Category | AI/ML |
| Tags | multica, ai-agents, coding-agents, claude-code, codex, issue-tracker, project-management, postgres, redis |
| Icon | `https://cdn.jsdelivr.net/gh/multica-ai/multica@v0.6.2/apps/web/public/favicon.svg` (upstream's own favicon, pinned to the release tag; returns 200 `image/svg+xml`) |

The description is delivered as written: issues are assigned to agents in the Multica board, agents run either on the user's own machines (Multica CLI daemon) or on the included **Agent Runtime** service on Railway, and every run (status, messages, usage) is recorded in Postgres and shown in the issue timeline. The Agent Runtime needs one post-deploy step (a personal access token plus an API key or subscription login), which the README states.

## Base market template

Three market templates exist (`_market/*.json`, all unverified, small):

| Code | Activity | Source | Assessment |
|---|---|---|---|
| `multica` | 11 active / 33 total (leader) | `RockinPaul/multica_railway_template` (no license, read only) | One-line `FROM` Dockerfiles over official images **v0.4.41** (outdated), web proxies to backend over the private network, backend also public for daemons, uploads on a volume, `pgvector/pgvector:pg17`, `ALLOW_SIGNUP=true` (open sign-up), relies on the web image to proxy the browser WebSocket. |
| `multica-prebuilt` | 2 active | images `ghcr.io/hmseeb/multica-*` (patched fork, digest-pinned) | Adds an unofficial owner-password login patch on v0.5.1; diverges from upstream and cannot be upgraded with official images. Sets `MULTICA_TRUSTED_PROXIES=0.0.0.0/0,::/0`, which trusts forwarded-IP headers from anyone. |
| `multica-ai` | 1 active | official images on `latest` | Unpinned `latest` tags; Postgres exposed on a public TCP proxy with `RAILWAY_RUN_UID=0`; browser pointed at the backend's public domain (`NEXT_PUBLIC_API_URL`, `NEXT_PUBLIC_WS_URL`) without `COOKIE_DOMAIN`, a split-host layout that upstream documents as breaking writes with `403 CSRF validation failed`. |

**Base: `multica`** (most deploys, closest to upstream). Kept: official images, the web app forwarding API calls to the backend over the private network, migrations before serving, `MULTICA_DAEMON_SERVER_URL`-style daemon guidance, optional variables defaulting to empty (not a space). Changed: see "Improvements" below. No files or README text were copied from any market template or repository.

## Pinned versions

| Service | Image / source | Tag | Released | Checked |
|---|---|---|---|---|
| Multica Web | `ghcr.io/multica-ai/multica-web` (official) | `v0.6.2` (latest stable, linux/amd64 present) | 2026-10-13 | 2026-10-13 (`docker buildx imagetools inspect`) |
| Multica Backend | `ghcr.io/multica-ai/multica-backend` (official) | `v0.6.2` | 2026-10-13 | 2026-10-13 |
| Agent Runtime | repo `baranberkay96/multica-railway`, `/services/agent-runtime` | `multica` CLI from backend `v0.6.2`, `node:22.23.3-bookworm-slim`, Claude Code `2.1.296` (2026-10-09), Codex `0.162.1` (2026-10-09) | n/a | 2026-10-13 (tags/npm versions checked; build **not run**, see Open questions) |
| Gateway | repo `baranberkay96/multica-railway`, `/services/gateway` | `caddy:2.11.7-alpine` (Caddy v2.11.7, latest) | 2026-10-03 | 2026-10-13 |
| Postgres | `ghcr.io/railwayapp-templates/postgres-ssl` (Railway base) | `17` | Railway base | 2026-10-13 |
| Redis | `redis` (Railway base) | `8.2` | Railway base | 2026-10-13 |
| Bucket | Railway Storage Bucket | n/a | n/a | n/a |

Postgres uses major **17** instead of the Railway base's 18: upstream states "Multica requires PostgreSQL 17" and its CI runs only on 17. Multica does not use pgvector (upstream: the `pgvector` image name is historical), so the stock Railway Postgres image with `pgcrypto` and `pg_trgm` (both in contrib) is enough.

**Upgrade**: bump `v0.6.2` on Multica Web and Multica Backend and `MULTICA_VERSION` in `services/agent-runtime/Dockerfile` to the same release, then deploy. Migrations run in the backend's pre-deploy step and are forward-only, so take a Postgres backup first. Rename the listing when the minor version changes (e.g. `v0.7`).

## Architecture

```
 Browser / CLI / local daemons
        │ HTTPS + WSS (one public domain)
        ▼
  Gateway (Caddy :8080)  /_gateway/health
        │  /ws, /api/daemon/ws, /health ──────────────┐
        │  everything else                             │
        ▼                                              ▼
  Multica Web (Next.js :3000)  ── /api /auth /v1 /uploads ──►  Multica Backend (Go :8080)  /readyz
                                                                 │  pre-deploy: /app/migrate up
  Agent Runtime (multica daemon + Claude Code + Codex) ──────────┤  (private http/ws)
     volume /home/agent (workspaces, CLI logins)                 ├──► Postgres :5432 (volume)
                                                                 ├──► Redis :6379 (volume)
                                                                 └──► Bucket (S3 API)
```

Only the Gateway has a public domain. This is upstream's documented **single-origin** layout (self-host quickstart): the web image forwards HTTP API calls but "cannot proxy WS upgrades", so the browser realtime socket, the daemon socket and the CLI health probe go straight to the backend. Browser, CLI and daemons all use one URL; cookies stay host-only, so `COOKIE_DOMAIN` is not needed.

## Services

### Gateway

| Setting | Value |
|---|---|
| Source | repo `baranberkay96/multica-railway`, root `/services/gateway` (`FROM caddy:2.11.7-alpine` + `Caddyfile`) |
| Start | image default (`caddy run --config /etc/caddy/Caddyfile --adapter caddyfile`) |
| Healthcheck | `/_gateway/health` (answered by Caddy itself), timeout 300 s |
| Public domain | yes, target port 8080 (`PORT=8080`, listens on all interfaces, dual-stack) |
| Restart | ALWAYS |
| Volume | none |

Routes `/health`, `/ws`, `/api/daemon/ws` to `MULTICA_BACKEND_UPSTREAM` and everything else to `MULTICA_WEB_UPSTREAM` (`flush_interval -1` for WebSockets, `lb_try_duration 10s` to ride out upstream restarts). `trusted_proxies static private_ranges 100.64.0.0/10` lets Caddy append the real client address to `X-Forwarded-For` instead of replacing it with the edge's.

### Multica Web

| Setting | Value |
|---|---|
| Source | image `ghcr.io/multica-ai/multica-web:v0.6.2` (runs as `nextjs`, `node apps/web/server.js`) |
| Healthcheck | `/login`, timeout 300 s |
| Public domain | no (reached through the Gateway) |
| Restart | ALWAYS |
| Variables | `PORT=3000`, `HOSTNAME=::` (dual-stack), `REMOTE_API_URL=http://${{Multica Backend.RAILWAY_PRIVATE_DOMAIN}}:${{Multica Backend.PORT}}` (read at runtime by the image's `proxy.ts`), `DOCS_URL=https://multica.ai` |

`NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_WS_URL` are deliberately not set: empty values make the browser use same-origin `/api` and `/ws`, which is upstream's recommended layout.

### Multica Backend

| Setting | Value |
|---|---|
| Source | image `ghcr.io/multica-ai/multica-backend:v0.6.2` (entrypoint runs `migrate up` again, a no-op, then `./server`) |
| Pre-deploy | `/app/migrate up`, timeout 1200 s; waits for Postgres up to `MULTICA_DATABASE_STARTUP_TIMEOUT=15m` |
| Healthcheck | `/readyz` (`{"status":"ok","checks":{"db":"ok","migrations":"ok"}}`), timeout 600 s |
| Public domain | no |
| Restart | ALWAYS |
| Replicas | 1 by default; stateless (files in the Bucket, realtime relay in Redis), so replicas can be raised |
| Volume | none (uploads go to the Bucket) |

Key variables (all described in `template.json`):

| Variable | Default | Why |
|---|---|---|
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Private Postgres. |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Without Redis the backend logs "auth rate limiting disabled"; with it, per-IP limits on `/auth/send-code` (5/min) and `/auth/verify-code` (20/min), the cross-replica realtime relay and task-claim caches. |
| `JWT_SECRET` | `secret(64, hex)` | Required; production refuses empty/known values. |
| `ALLOWED_EMAILS` | **user input (required)** | First-user bootstrap, see below. |
| `ALLOW_SIGNUP` | `false` | Sign-up only for `ALLOWED_EMAILS`, `ALLOWED_EMAIL_DOMAINS` and invitations. |
| `FRONTEND_ORIGIN` | `https://${{Gateway.RAILWAY_PUBLIC_DOMAIN}}` | CORS, WebSocket origin check, `Secure` cookies. `CORS_ALLOWED_ORIGINS`, `MULTICA_APP_URL`, `MULTICA_PUBLIC_URL`, `GOOGLE_REDIRECT_URI` reference it, so a custom domain is a one-variable change. |
| `S3_BUCKET`, `S3_REGION`, `AWS_ENDPOINT_URL`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | `${{Bucket.*}}` | Multica's S3 storage (takes priority over local disk). |
| `S3_USE_PATH_STYLE` | `false` | Railway Buckets are virtual-hosted style; Multica otherwise defaults to path-style when an endpoint is set. Multica already drops the aws-chunked checksum trailer for non-AWS endpoints. |
| `ATTACHMENT_DOWNLOAD_MODE` | `proxy` | Files stream through the backend: the bucket stays private and needs no CORS rules (presigned redirects would make the browser fetch from the bucket host). |
| `RATE_LIMIT_TRUSTED_PROXIES`, `MULTICA_TRUSTED_PROXIES` | private ranges + `100.64.0.0/10` + `fd00::/8` | The backend only sees the Gateway/web container; without this every user shares one rate-limit bucket. Only private-network peers can set the header. |
| `MULTICA_VCS_INTEGRATION_ENABLED` / `MULTICA_VCS_SECRET_KEY` | `true` / generated | Self-hosted Gitea/Forgejo/GitLab integration, on by default in upstream's compose but useless there without a key. |
| `MULTICA_PLUGIN_SECRET_KEY`, `MULTICA_SLACK_SECRET_KEY`, `MULTICA_TELEGRAM_SECRET_KEY` | generated | Enable plugin secrets and bring-your-own Slack/Telegram bots. Each must be base64 of 32 bytes: `secret(43, base64 alphabet)` + `=` decodes to 32 bytes with Go's (non-strict) `base64.StdEncoding`. An invalid key only disables that integration (logged), it never blocks boot. |
| `DATABASE_MAX_CONNS` | `20` | Headroom for 3-4 replicas under Postgres' default 100 connections. |
| `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `GOOGLE_*`, `DISABLE_WORKSPACE_CREATION`, `DO_NOT_TRACK` | empty / `false` | Optional, see README. |

Not set on purpose: `COOKIE_DOMAIN` (single origin), `LOCAL_UPLOAD_*` (Bucket), `MULTICA_DEV_VERIFICATION_CODE` (never on a public instance), `SMTP_*` (outbound SMTP needs Railway Pro; Resend's HTTP API is used instead), `MULTICA_LARK_*`/`DINGTALK`/`WECOM` keys (add a base64 32-byte key to enable), `MULTICA_LLM_*` (optional server-side helper LLM), `GITHUB_APP_*` (GitHub App integration, needs your own App).

### Agent Runtime

| Setting | Value |
|---|---|
| Source | repo `baranberkay96/multica-railway`, root `/services/agent-runtime` |
| Image | `node:22.23.3-bookworm-slim` + `git`, `openssh-client`, `ripgrep`, `curl`; Claude Code `2.1.296` and Codex `0.162.1` from npm; `multica` CLI copied unmodified from `multica-backend:v0.6.2` with its `LICENSE` and `NOTICE` |
| Entrypoint | `multica-runtime`: fixes volume ownership, drops to user `agent` (uid 1001) with `setpriv` (keeps working dir and env), waits for `MULTICA_SERVER_URL/health`, `multica login --token`, then `exec multica daemon start --foreground --no-auto-update --no-auto-reload` |
| Healthcheck | none (worker, no HTTP listener) |
| Restart | ALWAYS |
| Volume | `/home/agent` (= `HOME`: CLI config and daemon identity, `multica_workspaces/` repo checkouts, Claude/Codex logins) |
| Replicas | 1 (volume) |

Without `MULTICA_RUNTIME_TOKEN` the service prints the connect steps and sleeps (a few MB of RAM). The token is removed from the environment before the daemon starts, so agents never inherit it. Non-root is required: Claude Code refuses `bypassPermissions` under root, and Multica launches it in that mode. The daemon's identity is a UUID persisted on the volume, so redeploys keep the same runtime entry. Daemon traffic uses the private network (`http://multica-backend.railway.internal:8080`).

### Postgres, Redis, Bucket

Railway base definitions (`_railway-base/postgres.json` with the image major set to 17, `_railway-base/redis.json`), volumes at `/var/lib/postgresql/data` and `/data`. Bucket: Railway Storage Bucket named `Bucket`, private, virtual-hosted style.

## First login (first-user bootstrap)

1. At deploy time enter your email in **`ALLOWED_EMAILS`** (required). With `ALLOW_SIGNUP=false` nobody else can create an account, so the public URL is never an open instance.
2. Open the Gateway URL, enter that email and request a code.
3. Without an email provider the code is printed to the **Multica Backend** logs: `[DEV] Verification code for {email}: 123456` (Railway → Multica Backend → Logs, search "Verification code"). Codes expire after 10 minutes, allow 5 attempts, and one code per minute per email.
4. Create your workspace. Optionally set `DISABLE_WORKSPACE_CREATION=true` afterwards (upstream's recommended lock-down).
5. Teammates: invite them from the workspace (an invitation allows that email to sign up) or add their address/domain to `ALLOWED_EMAILS` / `ALLOWED_EMAIL_DOMAINS`. For teammates, configure Resend so codes and invitations arrive by email instead of the log.

### Login / email decision

Multica signs in with emailed 6-digit codes (or Google OAuth); there is no password login upstream. Railway allows outbound SMTP only on Pro, so the template uses Multica's **Resend** HTTP API integration (`RESEND_API_KEY` + `RESEND_FROM_EMAIL` on a verified domain) as the email path and leaves SMTP undocumented in variables. With no key, upstream's built-in fallback prints codes to the backend log, which is enough for the owner's first login. The patched owner-password fork used by one market template was rejected: it is not upstream code.

## Connecting agents

- **Your own machine** (upstream's default): `brew install multica-ai/tap/multica` (or upstream's install script), then `multica setup self-host --server-url https://{domain} --app-url https://{domain}`. The daemon reaches `/api/daemon/ws` and `/health` through the Gateway. Settings → Runtimes lists the machine.
- **On Railway (Agent Runtime)**: Settings → API Token → create a token (choose "never" or a long expiry), set it as `MULTICA_RUNTIME_TOKEN` on Agent Runtime, add `ANTHROPIC_API_KEY` and/or `OPENAI_API_KEY`, deploy. For subscriptions instead of API keys: `railway ssh` into Agent Runtime, then `setpriv --reuid=agent --regid=agent --init-groups claude` (or `codex login --device-auth`); logins are stored on the volume. Private repositories need credentials for the `agent` user (e.g. an SSH key in `/home/agent/.ssh` or a Git credential helper).

## Scaling

- Multica Backend is stateless: raise replicas (Redis relays realtime events between replicas; the usage rollup scheduler is multi-replica safe). Keep `replicas × DATABASE_MAX_CONNS` under Postgres' `max_connections`. Upstream notes WeCom bots need the Redis relay, which is configured.
- Multica Web and Gateway are stateless and can also run more replicas.
- Agent Runtime: one replica per volume. Add a second runtime by duplicating the service (new volume, same or another token), or raise `MULTICA_DAEMON_MAX_CONCURRENT_TASKS` and the service's RAM.

## Improvements over market templates

1. **Current release, official images, pinned**: `v0.6.2` (market: v0.4.41 via wrapper repo, a patched fork on v0.5.1, or `latest`).
2. **Realtime that follows upstream's documented layout**: a Caddy gateway sends `/ws` and `/api/daemon/ws` straight to the backend, because upstream's v0.6.2 guide says the web image cannot proxy WebSocket upgrades. One origin for browser, CLI and daemons; no `COOKIE_DOMAIN`, no cross-host CSRF failures.
3. **Backend and database not public**: only the Gateway has a domain. One market template exposes Postgres on a TCP proxy; the others give the backend its own public domain.
4. **Closed by default**: `ALLOWED_EMAILS` is required and `ALLOW_SIGNUP=false`, so a fresh deploy is not an open sign-up instance (leader: `ALLOW_SIGNUP=true`).
5. **Redis added** for per-IP auth rate limiting, multi-replica realtime and claim caches (no market template has it; without it upstream logs that auth rate limiting is disabled), with trusted-proxy ranges limited to private networks instead of `0.0.0.0/0`.
6. **Railway Bucket for files** instead of a backend volume: the backend becomes stateless and scalable, files survive service rebuilds, and proxy download mode avoids bucket CORS.
7. **Migrations in a pre-deploy step** (`/app/migrate up`, 15-minute DB wait) so a failed migration stops the deploy instead of crash-looping, per Rule 8.6.
8. **Agent Runtime on Railway**: optional cloud runtime with the official CLI daemon, Claude Code and Codex, non-root, pinned, self-update disabled. Every market template requires a local machine.
9. **Integrations ready**: generated keys for self-hosted Git providers, plugins, Slack and Telegram (upstream leaves them empty, i.e. disabled).
10. **Postgres matches upstream**: Railway Postgres 17 without the unused pgvector extension, private only.

## Resource estimate

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month (Bucket storage billed separately, small for attachments). Estimates, not measured.

| Service | Idle RAM / CPU | Typical RAM / CPU | Notes |
|---|---|---|---|
| Gateway | 20 MB / ~0 | 40 MB / 0.01 vCPU | |
| Multica Web | 150 MB / 0.01 | 300 MB / 0.1 vCPU | Next.js standalone |
| Multica Backend | 60 MB / 0.01 | 200 MB / 0.1 vCPU | Go; more with many daemons/WebSockets |
| Postgres | 80 MB / 0.01 | 250 MB / 0.05 vCPU | |
| Redis | 10 MB / ~0 | 30 MB / 0.01 vCPU | |
| Agent Runtime | 5 MB idle without token; 50 MB with daemon | 1.0-1.5 GB / 0.5 vCPU with 1-2 agents running | Each Claude Code / Codex run adds 300-700 MB; `MULTICA_DAEMON_MAX_CONCURRENT_TASKS=4` |
| Volumes | ~1.2 GB | Postgres 1-2 GB, Redis <0.1 GB, Agent Runtime 2-10 GB (repo checkouts) | |

Estimated monthly cost: **idle ≈ $4** (0.33 GB, ~0.05 vCPU, 1.2 GB volumes), **typical without cloud agents ≈ $14**, **typical with the Agent Runtime working ≈ $40** (2.3 GB × $10 + 0.77 vCPU × $20 + 6 GB × $0.15). Model usage is billed by the model provider or subscription.

Minimum plan: **Hobby**. The web stack would fit Trial's 1 GB per service, but the Agent Runtime needs more than 1 GB while agents run, and Hobby's 5 GB volume limit applies to its repo checkouts.

## License

Multica uses the **Multica License**: Apache-2.0 (Part II) plus additional conditions (Part I) from Index Labs (Hong Kong) Limited. Internal use within one organization is allowed without a commercial license; providing Multica as a hosted or managed service to third parties (even free) requires a commercial license; the Multica logo, product name and UI copyright/attribution must not be removed or modified; non-UI use (backend, daemon, CLI) must keep notices and state it is built on Multica. This template runs the official images unmodified, copies the official `multica` binary unmodified into the Agent Runtime together with `LICENSE` and `NOTICE`, and changes no branding. Each deployer operates their own instance and is responsible for staying within internal use or obtaining a commercial license. Details in NOTICE.md.

## Verification checklist

Nothing below has been run yet (see Open questions); this is the first-deploy test plan.

- [ ] All services build/deploy: Gateway and Agent Runtime images build on Railway; Multica Backend pre-deploy logs `migrate up` finishing; no `secretbox: ... is not valid base64` lines (the backend should log `vcs integration enabled`, `Plugin secret encryption enabled`).
- [ ] `GET https://{domain}/_gateway/health` → 200; `GET https://{domain}/health` → `{"status":"ok"}`; backend healthcheck `/readyz` green.
- [ ] `GET https://{domain}/api/config` shows `allow_signup: false` and `"daemon_server_url":"https://{domain}"`.
- [ ] Sign-in: a code requested for an address **not** in `ALLOWED_EMAILS` is refused (403); the allowed address gets a code in the backend log and signs in; workspace creation works.
- [ ] Realtime: open the board in two tabs, create an issue in one, it appears in the other without refresh (browser WebSocket via Gateway `/ws`).
- [ ] Upload an attachment and an avatar; objects appear in the Bucket; both download/display again (proxy mode).
- [ ] Local daemon: `multica setup self-host --server-url https://{domain} --app-url https://{domain}` connects; Settings → Runtimes shows it online.
- [ ] Agent Runtime: logs show the idle message before a token; after setting `MULTICA_RUNTIME_TOKEN` + an API key it logs in, the "Railway" runtime appears online, and an issue assigned to a Claude Code or Codex agent runs to completion with messages in the timeline.
- [ ] Rate limiting: backend logs no "auth rate limiting disabled" warning; repeated `send-code` calls from one client hit 429 while another client is unaffected (confirms forwarded client IPs).
- [ ] Persistence: redeploy every service; account, workspace, issues, files and the Agent Runtime registration (same runtime, no duplicate) survive.

## Open questions

- **No local run was possible.** The shared Docker daemon froze and the host disk filled during this session; the coordinator stopped all Docker work. The Gateway and Agent Runtime Dockerfiles were **not built**, and the stack was **not run** locally. Only registry/tag checks, npm version checks, a `sh -n` syntax check of the entrypoint and static review of upstream code/docs were done. The Railway deploy test is the first real verification.
- Caddyfile syntax was written from Caddy's documented directives (`trusted_proxies static private_ranges`, `client_ip_headers`, snippets, `{$PORT:8080}`) but not validated with `caddy validate`.
- Whether Railway's edge connects from a private/CGNAT address (needed for the trusted-proxy chain) is undocumented. If not, rate limits fall back to per-edge-IP buckets (degraded, not broken).
- The leader template states the web image proxied the browser WebSocket on v0.4.41, while upstream's v0.6.2 guide says it cannot; the Gateway makes this irrelevant, but it means the Gateway is a required hop.
- Railway Postgres 17 instead of upstream's `pgvector:pg17`: same major and extensions, not exercised.
- Agent Runtime: Claude Code's npm package installs a platform-native binary; the image build on Railway's amd64 builder is expected to work but is untested. Private-repository credentials for agents are left to the user.
- Railway `secret()` with `+` and `/` in the charset, followed by a literal `=`, is assumed to produce a valid base64 key; if not, the four integrations stay disabled (non-fatal).
- The Bucket path relies on Multica's S3 client with `AWS_ENDPOINT_URL` and virtual-hosted addressing against Railway's Tigris-backed buckets; not exercised.
