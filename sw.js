/* GymBook service worker: keeps the app working with no signal.
   Bump VERSION whenever you upload changed files, so phones pick up the update. */
const VERSION = 'gymbook-v44';
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
  // cache: 'reload' skips the phone's own saved copies, so an update always gets the fresh files
  event.waitUntil(caches.open(VERSION).then(c => c.addAll(SHELL.map(u => new Request(u, { cache: 'reload' })))));
});

self.addEventListener('activate', event => {
  event.waitUntil(cleanup().then(() => self.clients.claim()));
});

/* delete saved copies from older versions (also re-run on each launch, in case the phone stopped it part-way) */
function cleanup() {
  return caches.keys().then(keys => Promise.all(
    keys.filter(k => k !== VERSION && k !== FONT_CACHE).map(k => caches.delete(k))
  ));
}
/* only ever read from this version's saved copy, never a leftover older one */
const fromCache = req => caches.open(VERSION).then(c => c.match(req, { ignoreSearch: req.mode === 'navigate' }));

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
    event.waitUntil(cleanup());
    event.respondWith(fromCache('./index.html').then(hit => hit || fetch(req)));
    return;
  }

  // Everything else from the app: saved copy first, network as a fallback
  event.respondWith(fromCache(req).then(hit => hit || fetch(req)));
});
