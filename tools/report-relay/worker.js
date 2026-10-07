// Cloudflare Worker: receives a "Report a problem" POST from the Nutrition
// app and files it as a GitHub issue. The app never holds a GitHub token —
// only this Worker does, as the GITHUB_TOKEN secret (a fine-grained PAT
// scoped to Issues: write on this one repo). See README.md for setup.

const REPO = 'DanielDaCool/nutrition-app';
const MAX_BODY_BYTES = 4096;
const MAX_DESCRIPTION_CHARS = 4000;

// Best-effort, per-isolate rate limit: Workers can run many isolates across
// edge locations, each with its own copy of this Map, and an isolate can be
// recycled at any time — so this caps abuse from one request stream, not a
// precise global quota. Good enough to stop a single misbehaving client;
// for anything stronger, add a Cloudflare dashboard rate-limiting rule on
// this route (no code needed) or switch this Map to Workers KV/Durable
// Objects for a shared count.
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000; // 1 hour
const RATE_LIMIT_MAX_REQUESTS = 5;
const recentRequestsByIp = new Map();

function isRateLimited(ip) {
  const now = Date.now();
  const timestamps = (recentRequestsByIp.get(ip) ?? []).filter(
    (t) => now - t < RATE_LIMIT_WINDOW_MS,
  );
  timestamps.push(now);
  recentRequestsByIp.set(ip, timestamps);
  return timestamps.length > RATE_LIMIT_MAX_REQUESTS;
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== 'POST') {
      return json(405, { error: 'POST only' });
    }

    const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
    if (isRateLimited(ip)) {
      return json(429, { error: 'Too many reports. Try again later.' });
    }

    const contentLength = Number(request.headers.get('Content-Length') ?? 0);
    if (contentLength > MAX_BODY_BYTES) {
      return json(413, { error: 'Report is too large.' });
    }

    let payload;
    try {
      const text = await request.text();
      if (text.length > MAX_BODY_BYTES) {
        return json(413, { error: 'Report is too large.' });
      }
      payload = JSON.parse(text);
    } catch {
      return json(400, { error: 'Invalid JSON body.' });
    }

    const { description, version, platform } = payload ?? {};
    if (!isNonEmptyString(description)) {
      return json(400, { error: 'description is required.' });
    }
    const trimmedDescription = description.trim().slice(0, MAX_DESCRIPTION_CHARS);
    const safeVersion = isNonEmptyString(version) ? version.trim() : 'unknown';
    const safePlatform = isNonEmptyString(platform) ? platform.trim() : 'unknown';

    if (!env.GITHUB_TOKEN) {
      return json(500, { error: 'Relay is not configured.' });
    }

    const issueBody =
      `${trimmedDescription}\n\n---\nVersion: ${safeVersion}\nPlatform: ${safePlatform}`;
    const githubResponse = await fetch(`https://api.github.com/repos/${REPO}/issues`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GITHUB_TOKEN}`,
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json',
        'User-Agent': 'nutrition-app-report-relay',
      },
      body: JSON.stringify({
        title: `User report (${safePlatform}, ${safeVersion})`,
        body: issueBody,
        labels: ['user report'],
      }),
    });

    if (!githubResponse.ok) {
      const body = await githubResponse.text();
      console.error(
        `GitHub issue create failed: ${githubResponse.status} ${body}`,
      );
      return json(502, {
        error: 'Could not file the report right now.',
        githubStatus: githubResponse.status,
      });
    }

    return json(201, { ok: true });
  },
};
