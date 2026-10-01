(() => {
  const sb = window.supabase.createClient(window.SUPABASE_CONFIG.url, window.SUPABASE_CONFIG.publishableKey);
  const unwrap = r => { if (r.error) throw r.error; return r.data; };
  async function call(name, action, body = {}) {
    const session = unwrap(await sb.auth.getSession()).session;
    if (!session) throw new Error('Sign in required.');
    const { data, error } = await sb.functions.invoke(name, { body: { ...body, action }, headers: { Authorization: `Bearer ${session.access_token}` } });
    if (error) {
      let message = error.message;
      try { const payload = await error.context.json(); message = payload.error || payload.message || message; } catch {}
      throw new Error(message);
    }
    if (data?.error) throw new Error(data.error);
    return data.data;
  }
  async function rpc(name, body) { return unwrap(await sb.rpc(name, body)); }
  const serviceMap = { 'fire-smoke': 'fire-smoke-containment', 'water-damage': 'water-damage-pipe-burst', 'roof-structure': 'structural-roof-tarping', sewage: 'sewage-drain-backup', environmental: 'environmental-remediation', 'wind-storm': 'wind-storm-damage' };
  const bookingReceipts = new Map();
  // Retain a receipt during attachment retries, so a partial upload never creates another opportunity.
  async function submitBooking(publicKey, { request, files }) {
    if (!request.location.postal_code) throw new Error('Enter a ZIP/postal code. Coordinates alone cannot determine service coverage.');
    const fingerprint = JSON.stringify({ publicKey, request });
    let receipt = bookingReceipts.get(fingerprint);
    if (!receipt) {
      const d = request.dispatch;
      const result = await rpc('submit_booking', {
        p_public_key: publicKey, p_full_name: request.customer.full_name, p_phone: request.customer.phone,
        p_email: request.customer.email, p_postal_code: request.location.postal_code,
        p_service_code: serviceMap[request.service_type] || request.service_type, p_priority: d.priority,
        p_damage_notes: request.damage_notes, p_preferred_date: d.preferred_date, p_preferred_window: d.time_window,
        p_notify_before_hours: d.arrival_notice ? 2 : 0, p_visibility: request.opportunity_type,
        p_latitude: request.location.coordinates?.latitude ?? null, p_longitude: request.location.coordinates?.longitude ?? null
      });
      receipt = { ...result, uploaded: new Set() }; bookingReceipts.set(fingerprint, receipt);
    }
    for (const f of files) {
      const signature = `${f.name}:${f.size}:${f.lastModified}`;
      if (receipt.uploaded.has(signature)) continue;
      const name = f.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const path = `${receipt.opportunity_id}/${receipt.upload_token}/${crypto.randomUUID()}-${name}`;
      unwrap(await sb.storage.from('opportunity-media').upload(path, f, { contentType: f.type, upsert: false }));
      await rpc('attach_media', { p_opportunity: receipt.opportunity_id, p_token: receipt.upload_token, p_path: path, p_file_name: f.name, p_mime: f.type, p_size: f.size });
      receipt.uploaded.add(signature);
    }
    return receipt;
  }
  async function mediaUrl(path) { return unwrap(await sb.storage.from('opportunity-media').createSignedUrl(path, 300)).signedUrl; }
  window.DisasterAPI = { sb, call, rpc, submitBooking, mediaUrl, unwrap };
})();
