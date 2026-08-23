/* GOEN service worker — アプリの見た目部分だけをキャッシュし、
   通信できないときも起動できるようにする。データ通信はキャッシュしない。 */
const CACHE = 'goen-v1';
const SHELL = [
  './', './index.html', './manifest.webmanifest',
  './assets/icon-192.png', './assets/icon-512.png', './assets/icon-180.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Supabase など外部への通信はそのまま通す
  if (url.origin !== self.location.origin) return;

  // HTML は「まず通信、だめならキャッシュ」（更新が反映されるように）
  if (req.mode === 'navigate' || (req.headers.get('accept') || '').includes('text/html')) {
    e.respondWith(
      fetch(req).then(r => {
        const copy = r.clone();
        caches.open(CACHE).then(c => c.put(req, copy));
        return r;
      }).catch(() => caches.match(req).then(r => r || caches.match('./index.html')))
    );
    return;
  }
  // それ以外は「まずキャッシュ」
  e.respondWith(
    caches.match(req).then(r => r || fetch(req).then(res => {
      const copy = res.clone();
      caches.open(CACHE).then(c => c.put(req, copy));
      return res;
    }))
  );
});
