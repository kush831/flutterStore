window.storePush = {
  _os: null,
  _pending: [],
  init(appId, cb) {
    window.OneSignalDeferred = window.OneSignalDeferred || [];
    window.OneSignalDeferred.push(async (OneSignal) => {
      await OneSignal.init({ appId: appId, serviceWorkerPath: 'OneSignalSDKWorker.js', allowLocalhostAsSecureOrigin: true });
      this._os = OneSignal;
      const pack = (n) => JSON.stringify({ data: n.additionalData || {}, title: n.title || '', body: n.body || '' });
      OneSignal.Notifications.addEventListener('foregroundWillDisplay', (e) => {
        if (cb('foreground', pack(e.notification))) e.preventDefault();
      });
      OneSignal.Notifications.addEventListener('click', (e) => { cb('click', pack(e.notification)); });
      OneSignal.User.PushSubscription.addEventListener('change', (c) => {
        cb('subscription', JSON.stringify({ id: (c.current && c.current.id) || '' }));
      });
      cb('subscription', JSON.stringify({ id: OneSignal.User.PushSubscription.id || '' }));
      this._pending.forEach((f) => f(OneSignal));
      this._pending = [];
    });
  },
  _run(fn) { return this._os ? Promise.resolve(fn(this._os)) : new Promise((res) => this._pending.push((o) => res(fn(o)))); },
  login(id) { return this._run((o) => o.login(id)); },
  logout() { return this._run((o) => o.logout()); },
  requestPermission() { return this._run((o) => o.Notifications.requestPermission()); },
  permission() { return !!(this._os && this._os.Notifications.permission); },
  optedIn() { return !!(this._os && this._os.User.PushSubscription.optedIn); },
  optIn() { return this._run((o) => o.User.PushSubscription.optIn()); },
  optOut() { return this._run((o) => o.User.PushSubscription.optOut()); },
};