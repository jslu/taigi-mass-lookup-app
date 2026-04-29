// Cloudflare Pages Function — proxies POST /api/tau to the ithuan endpoint.
// The upstream API only allows requests from suisiann.ithuan.tw, so we set
// that Origin server-side. Browsers hit our same-origin /api/tau and never
// see the cross-origin call.

export async function onRequestPost(context) {
  const body = await context.request.text();
  const upstream = await fetch('https://hokbu.ithuan.tw/tau', {
    method: 'POST',
    headers: {
      'content-type': 'application/x-www-form-urlencoded',
      'origin': 'https://suisiann.ithuan.tw',
      'referer': 'https://suisiann.ithuan.tw/',
    },
    body,
  });
  return new Response(upstream.body, {
    status: upstream.status,
    headers: {
      'content-type': upstream.headers.get('content-type') || 'application/json',
    },
  });
}
