(() => {
  'use strict';

  const api = window.DisasterAPI;
  const query = selector => document.querySelector(selector);
  const form = query('#access-form');
  const choices = query('#access-choices');
  const title = query('#access-title');
  const heading = query('#page-heading');
  const description = query('#page-description');
  const email = query('#email');
  const password = query('#password');
  const confirmField = query('#confirm-field');
  const confirmPassword = query('#confirm-password');
  const submit = query('#login-submit');
  const magic = query('#magic-link');
  const google = query('#google-auth');
  const feedback = query('#login-feedback');
  const loading = query('#auth-loading');
  const loadingText = query('#loading-text');
  const params = new URLSearchParams(location.search);
  let mode = null;
  let redirecting = false;

  function destination() {
    const fallback = new URL('index.html#dashboard', location.href);
    const raw = params.get('next');
    if (!raw) return fallback;
    try {
      const requested = new URL(raw, location.href);
      const base = new URL('./', location.href).pathname;
      const isLocal = requested.origin === location.origin && requested.pathname.startsWith(base);
      return isLocal && !requested.pathname.endsWith('/login.html') ? requested : fallback;
    } catch {
      return fallback;
    }
  }

  function callbackUrl() {
    const callback = new URL('login.html', location.href);
    const next = destination();
    callback.searchParams.set('next', `${next.pathname}${next.search}${next.hash}`);
    return callback.href;
  }

  function setBusy(active, text) {
    loading.hidden = !active;
    if (text) loadingText.textContent = text;
    [submit, magic, google, ...choices.querySelectorAll('button')].forEach(button => {
      button.disabled = active;
    });
  }

  function message(text = '', error = false) {
    feedback.textContent = text;
    feedback.classList.toggle('error', error);
  }

  function enterApplication() {
    if (redirecting) return;
    redirecting = true;
    setBusy(true, 'Opening your workspace…');
    location.replace(destination().href);
  }

  function proceed() {
    if (params.get('onboard') === '1') window.DisasterOnboarding.start();
    else enterApplication();
  }

  function show(nextMode) {
    mode = nextMode;
    const creating = mode === 'signup';
    choices.hidden = true;
    form.hidden = false;
    confirmField.hidden = !creating;
    confirmPassword.required = creating;
    password.autocomplete = creating ? 'new-password' : 'current-password';
    title.textContent = creating ? 'Create account' : 'Welcome back';
    heading.textContent = creating ? 'Create your account.' : 'Sign in to continue.';
    description.textContent = creating
      ? 'Start with your email. You will complete your profile after verification.'
      : 'Access your dashboard and continue where you left off.';
    submit.textContent = creating ? 'Create account' : 'Sign in';
    magic.hidden = creating;
    message();
    email.focus();
  }

  function reset() {
    mode = null;
    form.reset();
    choices.hidden = false;
    form.hidden = true;
    confirmField.hidden = true;
    confirmPassword.required = false;
    title.textContent = 'Choose an account action';
    heading.textContent = 'Sign in to continue.';
    description.textContent = 'Access your workspace, review recent activity, and pick up where you left off.';
    message();
  }

  choices.addEventListener('click', event => {
    const button = event.target.closest('[data-mode]');
    if (button) show(button.dataset.mode);
  });

  query('#access-back').addEventListener('click', reset);

  document.querySelectorAll('[data-password]').forEach(button => {
    button.addEventListener('click', () => {
      const input = query(`#${button.dataset.password}`);
      const visible = input.type === 'text';
      input.type = visible ? 'password' : 'text';
      button.textContent = visible ? 'Show' : 'Hide';
      button.setAttribute('aria-label', `${visible ? 'Show' : 'Hide'} ${input === confirmPassword ? 'password confirmation' : 'password'}`);
    });
  });

  google.addEventListener('click', async () => {
    message();
    setBusy(true, 'Connecting to Google…');
    try {
      api.unwrap(await api.sb.auth.signInWithOAuth({
        provider: 'google',
        options: { redirectTo: callbackUrl() }
      }));
    } catch (error) {
      message(error.message || 'Unable to continue with Google.', true);
      setBusy(false);
    }
  });

  magic.addEventListener('click', async () => {
    message();
    if (!email.reportValidity()) return;
    setBusy(true, 'Sending your sign-in link…');
    try {
      api.unwrap(await api.sb.auth.signInWithOtp({
        email: email.value.trim(),
        options: { shouldCreateUser: false, emailRedirectTo: callbackUrl() }
      }));
      setBusy(false);
      message('Check your email for a secure sign-in link.');
    } catch (error) {
      setBusy(false);
      message(error.message || 'Unable to send the sign-in link.', true);
    }
  });

  form.addEventListener('submit', async event => {
    event.preventDefault();
    message();
    if (!form.reportValidity()) return;
    if (mode === 'signup' && password.value !== confirmPassword.value) {
      message('Passwords do not match.', true);
      confirmPassword.focus();
      return;
    }

    setBusy(true, mode === 'signup' ? 'Creating your account…' : 'Signing you in…');
    try {
      if (mode === 'signup') {
        const result = api.unwrap(await api.sb.auth.signUp({
          email: email.value.trim(),
          password: password.value,
          options: { emailRedirectTo: callbackUrl() }
        }));
        if (result.session) enterApplication();
        else {
          setBusy(false);
          message('Account created. Check your email to confirm it, then sign in.');
        }
      } else {
        api.unwrap(await api.sb.auth.signInWithPassword({
          email: email.value.trim(),
          password: password.value
        }));
        enterApplication();
      }
    } catch (error) {
      setBusy(false);
      message(error.message || 'Unable to continue.', true);
    }
  });

  api.sb.auth.onAuthStateChange(event => {
    if (event === 'SIGNED_IN') queueMicrotask(proceed);
  });

  (async () => {
    try {
      const { session } = api.unwrap(await api.sb.auth.getSession());
      if (session) proceed();
      else if (params.get('mode') === 'signup') show('signup');
    } catch (error) {
      message(error.message || 'Unable to check your session.', true);
    }
  })();
})();
