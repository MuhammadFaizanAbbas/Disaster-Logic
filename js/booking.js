(() => {
  const icon = window.icon;
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const dateKey = date => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);

  let serviceTypes = [
    { id: 'fire-smoke', title: 'Fire & Smoke Containment', icon: 'flame', tone: 'fire', description: 'Soot mitigation, smoke removal, and structural safety stabilization.', tag: 'Priority triage', detail: 'Immediate' },
    { id: 'water-damage', title: 'Water Damage / Pipe Burst', icon: 'droplet', tone: 'water', description: 'Emergency extraction, leak isolation, and structural drying.', tag: 'Water removal', detail: '24/7 response' },
    { id: 'roof-structure', title: 'Structural / Roof Tarping', icon: 'roof', tone: 'structure', description: 'Board-up, roof tarping, structural shoring, and storm damage.', tag: 'Stabilization', detail: 'Site safety' },
    { id: 'sewage', title: 'Sewage / Drain Backup', icon: 'briefcase', tone: 'sewage', description: 'Contaminated water extraction, sanitation, and drain cleanup.', tag: 'Biohazard response', detail: 'Containment' },
    { id: 'environmental', title: 'Environmental Remediation', icon: 'shield', tone: 'environment', description: 'Mold containment, environmental cleanup, and air quality control.', tag: 'Mold remediation', detail: 'Air quality' },
    { id: 'wind-storm', title: 'Wind / Storm Damage', icon: 'wind', tone: 'storm', description: 'Emergency storm recovery, debris removal, and property protection.', tag: 'Storm recovery', detail: 'Rapid response' }
  ];
  const windows = [ ['08:00-12:00', '8 AM – 12 PM'], ['12:00-16:00', '12 PM – 4 PM'], ['16:00-20:00', '4 PM – 8 PM'] ];
  const draft = {
    zip: '', service: '', fullName: '', phone: '', email: '', notes: '', opportunityType: '',
    priority: 'scheduled', date: dateKey(tomorrow), timeWindow: '12:00-16:00', arrivalNotice: true, coordinates: null
  };
  let form = null;
  let listeners = null;
  let files = [];
  let submitHandler = null;
  let submitting = false;
  let progressValue = -1;
  let requestReady = false;
  let dispatchTouched = false;
  let syncTimer = null;
  let stickyObserver = null;
  let headerObserver = null;
  const touchedDetails = new Set();
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const stepLabels = ['Location', 'Service Type', 'Customer Details', 'Timing & Dispatch'];
  const shortLabels = ['Location', 'Service', 'Details', 'Dispatch'];

  function serviceCard(service) {
    return `<label class="booking-service tone-${service.tone}">
      <input type="radio" name="service" value="${service.id}" ${draft.service === service.id ? 'checked' : ''} required>
      <span class="booking-choice-mark" aria-hidden="true"></span>
      <span class="booking-service-icon">${icon(service.icon, 20)}</span>
      <strong>${service.title}</strong><span class="booking-service-description">${service.description}</span>
      <span class="booking-service-meta"><span>${service.tag}</span><span>${service.detail}</span></span>
    </label>`;
  }

  function render() {
    return `<article class="booking-card">
      <header class="booking-header"><h1>Book Emergency & Disaster Repair</h1><p>Quick triage intake to get the right team to your property. Tell us what happened, where, and when.</p></header>
      <div class="booking-progress-anchor" aria-hidden="true"></div>
      <div class="booking-progress-shell">
        <button type="button" class="mobile-menu booking-menu" data-action="menu" aria-label="Open navigation" aria-controls="main-navigation" aria-expanded="false">${icon('menu', 21)}</button>
        <div class="booking-progress-track">
        <div class="booking-progress-meter" role="progressbar" aria-label="Booking completion" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" aria-valuetext="0% complete"><span class="booking-progress-fill"></span></div>
        <ol class="booking-progress" aria-label="Booking steps">
          ${stepLabels.map((label, index) => `<li data-booking-step="${index + 1}"><button type="button" class="booking-step-link" data-booking-go="${index + 1}" aria-label="Go to ${label}"><span class="booking-step-dot">${index + 1}</span><span class="booking-step-title">${label}</span><span class="booking-step-short">${shortLabels[index]}</span></button></li>`).join('')}
        </ol>
        </div>
        <span class="booking-progress-announcement" aria-live="polite" aria-atomic="true"></span>
      </div>
      <form id="booking-form" class="booking-form" novalidate>
        <div class="booking-step-panel" data-step-panel="1"><fieldset class="booking-section"><legend tabindex="-1"><span class="booking-section-number">1</span> Where do you need service?</legend>
          <div class="booking-location-row"><label class="booking-location-input">${icon('pin', 16)}<input name="zip" aria-label="ZIP code" autocomplete="postal-code" inputmode="numeric" placeholder="ZIP code" value="${escape(draft.zip)}" pattern="[0-9]{5}(-[0-9]{4})?" maxlength="10" required></label>
          <button type="button" class="booking-locate" data-booking-action="locate">${icon('target', 15)} Use location</button></div>
          <p class="booking-location-caption" data-location-message aria-live="polite">${icon('pin', 13)} <span>Enter your ZIP code to identify the service location.</span></p>
          <div class="booking-map" aria-label="Illustrated service area preview">
            <img src="assets/images/service-area.svg" alt="Illustrated street map with a service location marker" class="booking-map-image">
            <span class="booking-map-label">Area preview</span><span class="booking-map-pin">${icon('pin', 23)}</span>
            <div class="booking-map-controls"><button type="button" data-booking-action="zoom-in" aria-label="Zoom in on map preview">+</button><button type="button" data-booking-action="zoom-out" aria-label="Zoom out on map preview">−</button></div>
          </div>
        </fieldset></div>

        <div class="booking-step-panel" data-step-panel="2"><fieldset class="booking-section"><legend tabindex="-1"><span class="booking-section-number">2</span> Select Required Service Type</legend>
          <div class="booking-services">${serviceTypes.map(serviceCard).join('')}</div>
        </fieldset></div>

        <div class="booking-step-panel" data-step-panel="3"><fieldset class="booking-section"><legend tabindex="-1"><span class="booking-section-number">3</span> Customer Details & Damage Scope</legend>
          <div class="booking-contact-grid">
            <label class="booking-field"><span>Full name <span aria-hidden="true">*</span></span><input name="fullName" autocomplete="name" placeholder="Full name" value="${escape(draft.fullName)}" maxlength="120" aria-describedby="booking-name-error" required><small id="booking-name-error" class="booking-field-error" data-detail-error="fullName" aria-live="polite" hidden></small></label>
            <label class="booking-field"><span>Phone number <span aria-hidden="true">*</span></span><input name="phone" type="tel" autocomplete="tel" placeholder="+1 (555) 000-0000" value="${escape(draft.phone)}" maxlength="30" aria-describedby="booking-phone-error" required><small id="booking-phone-error" class="booking-field-error" data-detail-error="phone" aria-live="polite" hidden></small></label>
          </div>
          <label class="booking-field"><span>Email address for booking confirmation <span aria-hidden="true">*</span></span><input name="email" type="email" autocomplete="email" placeholder="s.jenkins@example.com" value="${escape(draft.email)}" maxlength="254" aria-describedby="booking-email-error" required><small id="booking-email-error" class="booking-field-error" data-detail-error="email" aria-live="polite" hidden></small></label>
          <label class="booking-field"><span>Urgent damage notes & access details</span><textarea name="notes" rows="4" maxlength="3000" placeholder="Tell us what happened, where the damage is, and any important access details. Include gate codes or site hazards if needed.">${escape(draft.notes)}</textarea></label>
          <label class="booking-upload" data-file-drop>
            <input class="booking-file-input" type="file" name="evidence" accept="image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime" multiple>
            <span class="booking-upload-icon">${icon('upload', 19)}</span>
            <strong>Drag photos or videos of damage here <span>or browse</span></strong>
            <span>JPG, PNG, WebP, MP4, WebM or MOV · Up to 5 files, 10 MB each</span>
            <span class="booking-upload-note">${icon('lock', 12)} Files stay on your device until your request is submitted.</span>
          </label>
          <ul class="booking-files" aria-label="Selected attachments" hidden></ul>
          <p class="booking-field-error" data-upload-error role="alert" hidden></p>
        </fieldset></div>

        <div class="booking-step-panel" data-step-panel="4"><fieldset class="booking-section"><legend tabindex="-1"><span class="booking-section-number">4</span> Dispatch Priority & Availability</legend>
          <div class="booking-dispatch-grid">
            <div class="booking-dispatch-card"><label class="booking-dispatch-choice"><input type="radio" name="priority" value="emergency" ${draft.priority === 'emergency' ? 'checked' : ''}><span class="booking-dispatch-icon emergency">${icon('flame', 20)}</span><strong>Emergency Dispatch</strong><span class="booking-choice-mark" aria-hidden="true"></span></label><p>Time-sensitive property damage? Request the earliest available emergency response.</p></div>
            <div class="booking-dispatch-card"><label class="booking-dispatch-choice"><input type="radio" name="priority" value="scheduled" ${draft.priority === 'scheduled' ? 'checked' : ''}><span class="booking-dispatch-icon">${icon('calendar', 19)}</span><strong>Scheduled Service Window</strong><span class="booking-choice-mark" aria-hidden="true"></span></label>
              <p>Select your preferred service date and arrival window.</p>
              <fieldset class="booking-schedule" aria-label="Preferred appointment time">
                <label class="booking-date-label"><span>Preferred date</span><input type="date" name="date" min="${dateKey(new Date())}" value="${escape(draft.date)}" required></label>
                <div class="booking-windows">${windows.map(([value, label]) => `<label><input type="radio" name="timeWindow" value="${value}" ${draft.timeWindow === value ? 'checked' : ''} required><span>${label}</span></label>`).join('')}</div>
                <label class="booking-notice"><input type="checkbox" name="arrivalNotice" ${draft.arrivalNotice ? 'checked' : ''}> Notify me 2 hours before arrival</label>
              </fieldset>
            </div>
          </div>
          <label class="booking-field booking-opportunity-type"><span>Opportunity type <span aria-hidden="true">*</span></span>
            <select name="opportunityType" required>
              <option value="" disabled ${!draft.opportunityType ? 'selected' : ''}>Select opportunity type</option>
              <option value="public" ${draft.opportunityType === 'public' ? 'selected' : ''}>Public</option>
              <option value="private" ${draft.opportunityType === 'private' ? 'selected' : ''}>Private</option>
            </select>
          </label>
        </fieldset></div>
        <div class="booking-actions">
        <p class="booking-result" role="status" aria-live="polite" tabindex="-1" hidden></p>
        <button class="booking-submit primary" type="submit">Confirm & Request ${icon('chevron', 15)}</button>
        </div>
      </form>
    </article>`;
  }

  function capture() {
    if (!form) return;
    // Read controls directly so switching dispatch modes preserves the schedule.
    for (const key of ['zip', 'service', 'fullName', 'phone', 'email', 'notes', 'priority', 'opportunityType']) draft[key] = form.elements.namedItem(key).value.trim();
    draft.date = form.elements.namedItem('date').value;
    draft.timeWindow = form.elements.namedItem('timeWindow').value;
    draft.arrivalNotice = form.elements.namedItem('arrivalNotice').checked;
  }

  function detailErrors() {
    const digits = draft.phone.replace(/\D/g, '');
    return {
      fullName: draft.fullName.length < 2 ? 'Enter your full name (at least 2 characters).' : '',
      phone: digits.length < 8 || digits.length > 15 ? 'Enter a phone number with 8–15 digits, including the area code.' : '',
      email: !draft.email || form.elements.namedItem('email').validity.typeMismatch ? 'Enter a valid email address, such as name@example.com.' : ''
    };
  }

  function showDetailErrors(errors, showAll = false) {
    for (const [key, message] of Object.entries(errors)) {
      const input = form.elements.namedItem(key);
      const error = form.querySelector(`[data-detail-error="${key}"]`);
      const show = Boolean(message) && (showAll || touchedDetails.has(key));
      input.setCustomValidity(message);
      if (show) input.setAttribute('aria-invalid', 'true'); else input.removeAttribute('aria-invalid');
      error.textContent = show ? message : '';
      error.hidden = !show;
    }
  }

  function goToStep(step) {
    const panel = form?.querySelector(`[data-step-panel="${step}"]`);
    if (!panel) return;
    panel.querySelector('legend').focus({ preventScroll: true });
    panel.scrollIntoView({ behavior: reducedMotion.matches ? 'instant' : 'smooth', block: 'start' });
  }

  function validateDispatch() {
    const date = form.elements.namedItem('date');
    const now = new Date();
    date.min = dateKey(now);
    date.setCustomValidity('');
    if (draft.priority === 'emergency') return true;
    if (draft.priority !== 'scheduled') return false;
    if (draft.date === dateKey(now) && Number(draft.timeWindow.slice(0, 2)) * 60 <= now.getHours() * 60 + now.getMinutes()) {
      date.setCustomValidity('Choose a future arrival window or another date.');
    }
    return date.validity.valid && windows.some(([value]) => value === draft.timeWindow);
  }

  function syncForm(announce = true) {
    if (!form) return;
    form.querySelector('.booking-schedule').disabled = draft.priority !== 'scheduled';
    form.elements.namedItem('zip').required = true;
    const zipValid = form.elements.namedItem('zip').validity.valid;
    const errors = detailErrors();
    const detailsValid = !Object.values(errors).some(Boolean);
    showDetailErrors(errors);
    const serviceValid = serviceTypes.some(service => service.id === draft.service);
    const dispatchValid = validateDispatch() && ['public', 'private'].includes(draft.opportunityType);
    const completed = [zipValid, serviceValid, detailsValid, dispatchValid && (dispatchTouched || (zipValid && serviceValid && detailsValid))];
    const current = completed.findIndex(value => !value);
    requestReady = completed.every(Boolean);
    // Each section contributes a quarter; contact fields fill their quarter gradually.
    const detailsProgress = Object.values(errors).filter(message => !message).length / 3;
    const fraction = (Number(zipValid) + Number(serviceValid) + detailsProgress + Number(completed[3])) / 4;
    const percent = Math.round(fraction * 100);
    const card = form.closest('.booking-card');
    card.querySelectorAll('[data-booking-step]').forEach((item, index) => {
      const isComplete = completed[index];
      item.classList.toggle('is-complete', isComplete);
      item.classList.toggle('is-current', index === current);
      if (index === current) item.setAttribute('aria-current', 'step'); else item.removeAttribute('aria-current');
      item.querySelector('.booking-step-dot').innerHTML = isComplete ? icon('check', 12) : String(index + 1);
    });
    const progress = card.querySelector('.booking-progress-shell');
    progress.style.setProperty('--booking-progress', String(fraction));
    progress.classList.toggle('has-progress', fraction > 0);
    progress.classList.toggle('is-finished', requestReady);
    const meter = progress.querySelector('[role="progressbar"]');
    const status = `${percent}% complete. ${requestReady ? 'Ready to request service.' : `${stepLabels[current]} needs to be completed.`}`;
    meter.setAttribute('aria-valuenow', String(percent));
    meter.setAttribute('aria-valuetext', status);
    if (announce && progressValue !== percent) {
      progress.querySelector('.booking-progress-announcement').textContent = status;
    }
    progressValue = percent;
    form.querySelector('[type="submit"]').disabled = submitting;
  }

  function setupStickyProgress() {
    const card = form.closest('.booking-card');
    const anchor = card.querySelector('.booking-progress-anchor');
    const progress = card.querySelector('.booking-progress-shell');
    const header = document.querySelector('.topbar');
    const observe = () => {
      const top = header ? Math.ceil(header.getBoundingClientRect().height) : 0;
      card.style.setProperty('--booking-sticky-top', `${top}px`);
      stickyObserver?.disconnect();
      const update = () => progress.classList.toggle('is-compact', anchor.getBoundingClientRect().top <= top);
      stickyObserver = new IntersectionObserver(update, { rootMargin: `-${top}px 0px 0px 0px`, threshold: [0, 1] });
      stickyObserver.observe(anchor);
      update();
    };
    if (header) {
      headerObserver = new ResizeObserver(observe);
      headerObserver.observe(header);
    }
    observe();
  }

  function renderFiles() {
    if (!form) return;
    const list = form.querySelector('.booking-files');
    list.hidden = files.length === 0;
    list.innerHTML = files.map((file, index) => `<li><span>${icon('check-square', 15)} <span>${escape(file.name)}</span><small>${(file.size / 1024 / 1024).toFixed(1)} MB</small></span><button type="button" data-remove-file="${index}" aria-label="Remove ${escape(file.name)}">${icon('close', 14)}</button></li>`).join('');
  }

  function selectFiles(incoming) {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm', 'video/quicktime'];
    const errors = [];
    for (const file of incoming) {
      if (!allowed.includes(file.type)) { errors.push(`${file.name}: choose a supported image or video.`); continue; }
      if (file.size > 10 * 1024 * 1024) { errors.push(`${file.name}: the maximum size is 10 MB.`); continue; }
      if (files.some(existing => existing.name === file.name && existing.size === file.size && existing.lastModified === file.lastModified)) continue;
      if (files.length >= 5) { errors.push('You can attach up to 5 files.'); break; }
      files.push(file);
    }
    const message = form.querySelector('[data-upload-error]');
    message.textContent = errors.join(' ');
    message.hidden = !errors.length;
    renderFiles();
  }

  function showLocation(message) {
    form?.querySelector('[data-location-message] span').replaceChildren(document.createTextNode(message));
  }

  function locate(button) {
    if (!navigator.geolocation) { showLocation('Location is unavailable in this browser. Please enter your ZIP code.'); return; }
    const activeForm = form;
    button.disabled = true;
    showLocation('Finding your location…');
    navigator.geolocation.getCurrentPosition(position => {
      if (form !== activeForm) return;
      draft.coordinates = { latitude: position.coords.latitude, longitude: position.coords.longitude };
      button.disabled = false;
      showLocation(`Location captured: ${draft.coordinates.latitude.toFixed(4)}, ${draft.coordinates.longitude.toFixed(4)}. Enter a ZIP code to match service coverage.`);
      syncForm();
    }, () => {
      if (form !== activeForm) return;
      button.disabled = false;
      showLocation('Location could not be accessed. Please enter your ZIP code.');
    }, { timeout: 12000, maximumAge: 60000 });
  }

  function payload() {
    capture();
    return {
      location: { postal_code: draft.zip.trim() || null, coordinates: draft.coordinates ? { ...draft.coordinates } : null },
      service_type: draft.service,
      opportunity_type: draft.opportunityType,
      customer: { full_name: draft.fullName.trim(), phone: draft.phone.trim(), email: draft.email.trim() },
      damage_notes: draft.notes.trim(),
      dispatch: {
        priority: draft.priority,
        preferred_date: draft.priority === 'scheduled' ? draft.date : null,
        time_window: draft.priority === 'scheduled' ? draft.timeWindow : null,
        arrival_notice: draft.priority === 'scheduled' && draft.arrivalNotice,
        time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone
      }
    };
  }

  async function submit(event) {
    event.preventDefault();
    if (submitting) return;
    clearTimeout(syncTimer);
    capture();
    syncForm(false);
    const activeForm = form;
    activeForm.classList.add('was-validated');
    Object.keys(detailErrors()).forEach(key => touchedDetails.add(key));
    showDetailErrors(detailErrors(), true);
    if (!activeForm.reportValidity() || !requestReady) return;
    const request = payload();
    const result = activeForm.querySelector('.booking-result');
    result.hidden = false;
    result.classList.remove('is-error');
    if (!submitHandler) {
      result.textContent = 'Your details are ready. This request has not been submitted.';
      activeForm.dispatchEvent(new CustomEvent('booking:prepared', { bubbles: true, detail: { request, files: [...files] } }));
      result.focus({ preventScroll: true });
      return;
    }
    const button = activeForm.querySelector('[type="submit"]');
    const originalLabel = button.innerHTML;
    submitting = true;
    button.disabled = true;
    button.textContent = 'Sending request…';
    result.textContent = '';
    try {
      // Integrate the API by registering an async handler that rejects failed requests.
      await submitHandler({ request, files: [...files] });
      result.textContent = 'Request received. We will contact you to confirm service availability.';
    } catch (error) {
      result.classList.add('is-error');
      result.textContent = error.message || 'Your request could not be sent. Your details are still here; please try again.';
    } finally {
      submitting = false;
      button.disabled = false;
      button.innerHTML = originalLabel;
      if (form !== activeForm) syncForm(false);
    }
  }

  function mount(element) {
    form = element;
    listeners = new AbortController();
    const options = { signal: listeners.signal };
    const dropZone = form.querySelector('[data-file-drop]');
    let zoom = 1;
    form.addEventListener('input', event => {
      event.target.setCustomValidity?.('');
      if (['priority', 'date', 'timeWindow', 'arrivalNotice', 'opportunityType'].includes(event.target.name)) dispatchTouched = true;
      capture();
      if (event.target.name === 'zip') {
        draft.coordinates = null;
        showLocation(/^\d{5}(-\d{4})?$/.test(draft.zip) ? `Service ZIP: ${draft.zip}. Availability will be confirmed with your request.` : 'Enter your ZIP code to identify the service location.');
      }
      const message = form.querySelector('.booking-result');
      message.hidden = true;
      clearTimeout(syncTimer);
      syncTimer = setTimeout(() => syncForm(), 220);
    }, options);
    form.addEventListener('change', event => {
      if (event.target.type === 'file') { selectFiles(event.target.files); event.target.value = ''; }
      clearTimeout(syncTimer);
      if (['priority', 'date', 'timeWindow', 'arrivalNotice', 'opportunityType'].includes(event.target.name)) dispatchTouched = true;
      capture(); syncForm();
    }, options);
    form.addEventListener('focusout', event => {
      if (event.relatedTarget?.matches('[type="submit"]')) return;
      if (['fullName', 'phone', 'email'].includes(event.target.name)) touchedDetails.add(event.target.name);
      clearTimeout(syncTimer);
      capture(); syncForm();
    }, options);
    form.addEventListener('click', event => {
      const button = event.target.closest('[data-booking-action], [data-remove-file]');
      if (!button) return;
      if (button.dataset.removeFile !== undefined) { files.splice(Number(button.dataset.removeFile), 1); renderFiles(); }
      if (button.dataset.bookingAction === 'locate') locate(button);
      if (button.dataset.bookingAction?.startsWith('zoom-')) {
        zoom = Math.max(1, Math.min(1.8, zoom + (button.dataset.bookingAction === 'zoom-in' ? .2 : -.2)));
        form.querySelector('.booking-map-image').style.transform = `scale(${zoom})`;
      }
    }, options);
    for (const eventName of ['dragenter', 'dragover']) dropZone.addEventListener(eventName, event => { event.preventDefault(); dropZone.classList.add('is-dragging'); }, options);
    dropZone.addEventListener('dragleave', () => dropZone.classList.remove('is-dragging'), options);
    dropZone.addEventListener('drop', event => { event.preventDefault(); dropZone.classList.remove('is-dragging'); selectFiles(event.dataTransfer.files); }, options);
    form.addEventListener('submit', submit, options);
    form.closest('.booking-card').addEventListener('click', event => {
      const button = event.target.closest('[data-booking-go]');
      if (!button || button.disabled) return;
      goToStep(Number(button.dataset.bookingGo));
    }, options);
    if (draft.coordinates) showLocation(`Location captured: ${draft.coordinates.latitude.toFixed(4)}, ${draft.coordinates.longitude.toFixed(4)}. Enter a ZIP code to match service coverage.`);
    else if (draft.zip) showLocation(`Service ZIP: ${draft.zip}. Availability will be confirmed with your request.`);
    progressValue = -1;
    syncForm(false); renderFiles(); setupStickyProgress();
  }

  function unmount() {
    capture();
    clearTimeout(syncTimer);
    stickyObserver?.disconnect();
    headerObserver?.disconnect();
    stickyObserver = null;
    headerObserver = null;
    listeners?.abort();
    listeners = null;
    form = null;
  }

  window.BookingView = Object.freeze({
    render, mount, unmount,
    getPayload: payload,
    setServices(services) {
      const tones = ['fire', 'water', 'structure', 'sewage', 'environment', 'storm'];
      serviceTypes = services.map((s, i) => ({ id: s.code, title: s.name, description: s.description || '', tag: s.tag || '', detail: s.response_label || '', tone: tones[i % 6], icon: 'shield' }));
      if (!serviceTypes.some(s => s.id === draft.service)) draft.service = '';
    },
    setSubmitHandler(handler) {
      if (handler !== null && typeof handler !== 'function') throw new TypeError('Expected an async booking submission function.');
      submitHandler = handler;
    }
  });
})();
