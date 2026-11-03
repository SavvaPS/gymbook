/* GymBook service worker: keeps the app working with no signal.
   Bump VERSION whenever you upload changed files, so phones pick up the update. */
const VERSION = 'gymbook-v9';
const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-192.png',
  './icons/maskable-512.png',
  './icons/apple-touch-icon.png',
  './icons/favicon-32.png'
];
const FONT_CACHE = 'gymbook-fonts';

self.addEventListener('install', event => {
  event.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL)));
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== VERSION && k !== FONT_CACHE).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

/* the page asks the new version to take over when you tap "Reload" */
self.addEventListener('message', event => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

self.addEventListener('fetch', event => {
  const req = event.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Google Fonts: keep a copy so the type looks right offline
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(caches.open(FONT_CACHE).then(async cache => {
      const hit = await cache.match(req);
      if (hit) return hit;
      try {
        const res = await fetch(req);
        if (res.ok || res.type === 'opaque') cache.put(req, res.clone());
        return res;
      } catch (e) {
        return hit || Response.error();
      }
    }));
    return;
  }

  if (url.origin !== self.location.origin) return;

  // Opening the app: serve the saved copy instantly, so it starts with no signal
  if (req.mode === 'navigate') {
    event.respondWith(caches.match('./index.html').then(hit => hit || fetch(req)));
    return;
  }

  // Everything else from the app: saved copy first, network as a fallback
  event.respondWith(caches.match(req).then(hit => hit || fetch(req)));
});
