# Report relay

A tiny Cloudflare Worker that turns a "Report a problem" message from the
app into a GitHub issue on this repo, without the app ever holding a GitHub
token (friends have no GitHub account, and a token shipped inside a public
app would leak).

The app POSTs `{description, version, platform}` to this Worker's URL. The
Worker holds a GitHub token as a secret and files the issue; nothing else
reaches it. GitHub's own repo-notification email reaches Daniel, so the
Worker doesn't send email itself — just make sure notifications for this
repo go to the address you want (GitHub → Settings → Notifications).

## One-time setup

1. **A Cloudflare account** (free tier is enough): https://dash.cloudflare.com/sign-up
2. **Install Wrangler** (Cloudflare's CLI), from this directory:
   ```
   npm install -g wrangler
   wrangler login
   ```
3. **A GitHub token scoped to Issues only**, so a Worker compromise can at
   worst spam issues, not touch code or settings:
   - GitHub → Settings → Developer settings → Personal access tokens →
     Fine-grained tokens → Generate new token.
   - Resource owner: `DanielDaCool`. Repository access: only this repo.
   - Permissions: **Issues: Read and write**. Nothing else.
   - Set an expiry and note it somewhere, since the token stops working
     when it expires and reports will fail silently until it's renewed.
4. **Store the token as a Worker secret** (never in this repo, never pasted
   into chat):
   ```
   wrangler secret put GITHUB_TOKEN
   ```
   Paste the token when prompted.
5. **Deploy**:
   ```
   wrangler deploy
   ```
   This prints the Worker's URL, like
   `https://nutrition-report-relay.<your-subdomain>.workers.dev`.
6. **Wire the URL into CI**: add it as the `REPORT_RELAY_URL` repository
   secret (GitHub → Settings → Secrets and variables → Actions). Both
   `ci.yml` (Android) and `web.yml` (web) already pass it through as
   `--dart-define=REPORT_RELAY_URL=...`; without the secret set, the app
   builds with an empty URL and "Report a problem" fails gracefully
   (a "couldn't send, try again" message) instead of doing anything.

## Limits

- Request bodies over 4&nbsp;KB and descriptions over 4,000 characters are
  rejected.
- A basic per-IP rate limit (5 requests/hour) runs inside the Worker. It's
  best-effort — Cloudflare can run several isolates of the same Worker
  across edge locations, each with its own counter, and an idle isolate can
  be recycled at any time — so treat it as a soft cap on one client, not a
  hard global quota. For a stronger guarantee with no code change, add a
  rate-limiting rule for this route in the Cloudflare dashboard
  (Security → WAF → Rate limiting rules); for a precise shared count,
  switch `recentRequestsByIp` to Workers KV or a Durable Object.
- Every report lands as a public GitHub issue (this repo is public) labelled
  `user report`, titled with the platform and app version. Friends
  shouldn't put anything personal in a report.

## Testing locally

```
wrangler dev
```
Then `curl -X POST http://localhost:8787 -H 'Content-Type: application/json' -d '{"description":"test","version":"0.0.0+2","platform":"Android"}'` —
set `GITHUB_TOKEN` in `.dev.vars` (gitignored) first if you want it to
actually file an issue; otherwise it'll fail at the GitHub call, which is
fine for checking the validation and CORS behavior.
