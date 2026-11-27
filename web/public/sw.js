// Офлайн-режим: приложение открывается без интернета уже после первого запуска.
const CACHE = 'daytrack-v2'
const SHELL = ['./', './index.html', './manifest.webmanifest', './icon-192.png', './icon-512.png', './apple-touch-icon.png']

// При установке сохраняются страница и все файлы, на которые она ссылается (код и стили).
self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE)
    await cache.addAll(SHELL)
    const html = await (await fetch('./index.html', { cache: 'no-store' })).text()
    const assets = [...html.matchAll(/(?:src|href)="(\.?\/?assets\/[^"]+)"/g)].map((m) => m[1])
    await cache.addAll(assets)
  })())
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))))
  self.clients.claim()
})

self.addEventListener('fetch', (event) => {
  const request = event.request
  if (request.method !== 'GET' || new URL(request.url).origin !== location.origin) return
  const url = new URL(request.url)
  // Файлы сборки с хешем в имени не меняются: сначала из сохранённого.
  if (url.pathname.includes('/assets/')) {
    event.respondWith(caches.match(request, { ignoreVary: true, ignoreSearch: true }).then((hit) => hit || fetch(request).then((response) => {
      const copy = response.clone()
      caches.open(CACHE).then((c) => c.put(request, copy))
      return response
    })))
    return
  }
  // Страница и прочее: сначала сеть (чтобы получать обновления), без сети — сохранённая копия.
  event.respondWith(
    fetch(request)
      .then((response) => {
        const copy = response.clone()
        caches.open(CACHE).then((c) => c.put(request, copy))
        return response
      })
      .catch(() => caches.match(request, { ignoreVary: true }).then((r) => r || caches.match('./index.html', { ignoreVary: true })))
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  event.waitUntil(self.clients.matchAll({ type: 'window' }).then((list) => (list[0] ? list[0].focus() : self.clients.openWindow('./'))))
})
