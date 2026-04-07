/**
 * Blue Viper — tek cihaz aktivasyonu (Cloudflare Worker + KV).
 *
 * KV'de anahtar: SHA-256(salt + 12_haneli_kod) hex
 * Değer: "__free__" (kullanılmamış) veya ilk bağlayan cihazın deviceId dizesi.
 *
 * Gizli: ACTIVATION_SALT — Flutter `kActivationSalt` ile aynı olmalı (varsayılan bvp_act_v1|).
 */

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

async function sha256Hex(text) {
  const enc = new TextEncoder().encode(text);
  const buf = await crypto.subtle.digest('SHA-256', enc);
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }
    if (request.method !== 'POST') {
      return json({ ok: false, error: 'method_not_allowed' }, 405);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: 'bad_json' }, 400);
    }

    const code = body?.code;
    const deviceId = body?.deviceId;

    if (!/^\d{12}$/.test(String(code || ''))) {
      return json({ ok: false, error: 'bad_code' }, 400);
    }
    if (typeof deviceId !== 'string' || deviceId.length < 4) {
      return json({ ok: false, error: 'bad_device' }, 400);
    }

    const salt = env.ACTIVATION_SALT ?? 'bvp_act_v1|';
    const hash = await sha256Hex(salt + code);

    const current = await env.ACTIVATION_KV.get(hash);
    if (current === null) {
      return json({ ok: false, error: 'unknown_code' }, 404);
    }

    if (current === '__free__') {
      await env.ACTIVATION_KV.put(hash, deviceId);
      return json({ ok: true, bound: true });
    }

    if (current === deviceId) {
      return json({ ok: true, bound: false });
    }

    return json({ ok: false, error: 'code_used_other_device' }, 403);
  },
};
