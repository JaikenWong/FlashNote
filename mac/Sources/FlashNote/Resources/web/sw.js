// sw.js · service worker：network-first 静态资源（避免缓存老代码）
// API 请求不拦截（数据走 localStorage + 同步 API）

const CACHE = 'flashnote-v2';
const ASSETS = [
  '/',
  '/index.html',
  '/css/app.css',
  '/js/app.js',
  '/js/parser.js',
  '/js/storage.js',
  '/js/sync.js',
  '/js/stats.js',
  '/manifest.json',
  '/images/icon-512.png'
];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).catch(() => {}));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // API 请求不缓存
  if (url.pathname.startsWith('/api/')) return;
  // 只处理同源 GET
  if (e.request.method !== 'GET') return;
  if (url.origin !== self.location.origin) return;

  // network-first：先尝试服务器，失败才用 cache
  // 这样代码改动能立刻生效（避免 service worker 缓存老 js 导致 bug）
  e.respondWith(
    fetch(e.request).then(resp => {
      if (resp.ok) {
        const clone = resp.clone();
        caches.open(CACHE).then(c => c.put(e.request, clone)).catch(() => {});
      }
      return resp;
    }).catch(() => caches.match(e.request).then(c => c || Response.error()))
  );
});
