(() => {
  'use strict';

  const api = window.DisasterAPI;
  const form = document.querySelector('#login-form');
  const nameField = document.querySelector('#name-field');
  const fullName = document.querySelector('#full-name');
  const email = document.querySelector('#email');
  const password = document.querySelector('#password');
  const submit = document.querySelector('#login-submit');
  const feedback = document.querySelector('#login-feedback');
  const modeToggle = document.querySelector('#mode-toggle');
  const modePrompt = document.querySelector('#mode-prompt');
  const magicLink = document.querySelector('#magic-link');
  const divider = document.querySelector('#login-divider');
  const togglePassword = document.querySelector('#toggle-password');
  const title = document.querySelector('#login-title');
  const kicker = document.querySelector('#login-kicker');
  const description = document.querySelector('#login-description');
  const params = new URLSearchParams(location.search);
  let mode = 'login';
  let redirecting = false;

  function destination() {
    const fallback = new URL('index.html#dashboard', location.href);
    const raw = params.get('next');
    if (!raw) return fallback;
    try {
      const target = new URL(raw, location.href);
      const appPath = new URL('./', location.href).pathname;
      if (target.origin !== location.origin || !target.pathname.startsWith(appPath) || target.pathname.endsWith('/login.html')) return fallback;
      return target;
    } catch {
      return fallback;
    }
  }

  function redirectUrl() {
    const callback = new URL('login.html', location.href);
    const target = destination();
    callback.searchParams.set('next', `${target.pathname}${target.search}${target.hash}`);
    return callback.href;
  }

  function enterApp() {
    if (redirecting) return;
    redirecting = true;
    location.replace(destination().href);
  }

  function message(text, isError = false) {
    feedback.textContent = text;
    feedback.classList.toggle('error', isError);
  }

  function setBusy(busy) {
    submit.disabled = busy;
    modeToggle.disabled = busy;
    magicLink.disabled = busy;
    submit.textContent = busy ? (mode === 'signup' ? 'Creating account…' : 'Signing in…') : (mode === 'signup' ? 'Create account' : 'Sign in');
  }

  function setMode(nextMode) {
    mode = nextMode;
    const signingUp = mode === 'signup';
    nameField.hidden = !signingUp;
    fullName.required = signingUp;
    password.autocomplete = signingUp ? 'new-password' : 'current-password';
    kicker.textContent = signingUp ? 'Get started' : 'Welcome back';
    title.textContent = signingUp ? 'Create your account' : 'Sign in to your account';
    description.textContent = signingUp ? 'Create an account, then confirm your email to continue.' : 'Enter your workspace email and password.';
    submit.textContent = signingUp ? 'Create account' : 'Sign in';
    modePrompt.textContent = signingUp ? 'Already have an account?' : 'New to Disaster Logic?';
    modeToggle.textContent = signingUp ? 'Sign in instead' : 'Create an account';
    magicLink.hidden = signingUp;
    divider.hidden = signingUp;
    message('');
    (signingUp ? fullName : email).focus();
  }

  document.querySelector('[data-action="theme"]').addEventListener('click', () => window.AdminTheme.toggle());
  togglePassword.addEventListener('click', () => {
    const visible = password.type === 'text';
    password.type = visible ? 'password' : 'text';
    togglePassword.textContent = visible ? 'Show' : 'Hide';
    togglePassword.setAttribute('aria-pressed', String(!visible));
  });
  modeToggle.addEventListener('click', () => setMode(mode === 'login' ? 'signup' : 'login'));

  magicLink.addEventListener('click', async () => {
    message('');
    if (!email.reportValidity()) return;
    setBusy(true);
    try {
      api.unwrap(await api.sb.auth.signInWithOtp({
        email: email.value.trim(),
        options: { shouldCreateUser: false, emailRedirectTo: redirectUrl() }
      }));
      message('Check your email for a secure sign-in link.');
    } catch (error) {
      message(error.message || 'Unable to send the sign-in link.', true);
    } finally {
      setBusy(false);
    }
  });

  form.addEventListener('submit', async event => {
    event.preventDefault();
    message('');
    if (!form.reportValidity()) return;
    setBusy(true);
    try {
      if (mode === 'signup') {
        const name = fullName.value.trim();
        if (!name) throw new Error('Enter your full name.');
        const result = api.unwrap(await api.sb.auth.signUp({
          email: email.value.trim(),
          password: password.value,
          options: { data: { full_name: name }, emailRedirectTo: redirectUrl() }
        }));
        if (result.session) enterApp();
        else message('Account created. Check your email to confirm your account.');
      } else {
        api.unwrap(await api.sb.auth.signInWithPassword({ email: email.value.trim(), password: password.value }));
        enterApp();
      }
    } catch (error) {
      message(error.message || 'Unable to sign in.', true);
    } finally {
      if (!redirecting) setBusy(false);
    }
  });

  api.sb.auth.onAuthStateChange(event => {
    if (event === 'SIGNED_IN') queueMicrotask(enterApp);
  });

  (async () => {
    try {
      const { session } = api.unwrap(await api.sb.auth.getSession());
      if (session) enterApp();
      else email.focus();
    } catch (error) {
      message(error.message || 'Unable to check your session.', true);
    }
  })();
})();
