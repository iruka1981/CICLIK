const CACHE = "ciclik-shell-v2";
const SCOPE_URL = self.registration.scope;
const SHELL_KEY = new URL("./", SCOPE_URL).href;
const PRECACHE = [
  "./",
  "./manifest.webmanifest",
  "logo-ciclik-transparent.png",
  "SLIDE%20PORTADA.webp",
  "SLIDE%203%20INTERCANVIO.webp",
  "SLIDE%20ROPA%20MERCADO.webp",
  "SLIDE%20COCINA.webp"
];
const CDN_SCRIPTS = [
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2",
  "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js",
  "https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.js"
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => Promise.all([
        ...PRECACHE.map((url) => cache.add(url).catch(() => {})),
        ...CDN_SCRIPTS.map((url) =>
          fetch(url, { mode: "cors", credentials: "omit" })
            .then((res) => res.ok && cache.put(url, res))
            .catch(() => {})
        )
      ]))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Serve from cache immediately and refresh the cached copy in the background.
function staleWhileRevalidate(event, cacheKey, networkRequest) {
  const update = caches.open(CACHE).then((cache) =>
    fetch(networkRequest).then((res) => {
      if (res.ok && !res.redirected) cache.put(cacheKey, res.clone());
      return res;
    })
  );
  event.waitUntil(update.catch(() => {}));
  return caches.match(cacheKey).then((cached) => cached || update);
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);

  if (CDN_SCRIPTS.includes(url.href)) {
    event.respondWith(
      staleWhileRevalidate(event, url.href, new Request(url.href, { mode: "cors", credentials: "omit" }))
    );
    return;
  }

  // Supabase/API and any other cross-origin traffic goes straight to the network.
  if (url.origin !== self.location.origin) return;

  if (req.mode === "navigate" && url.href.startsWith(SCOPE_URL)) {
    event.respondWith(
      staleWhileRevalidate(event, SHELL_KEY, req).catch(() => caches.match(SHELL_KEY))
    );
    return;
  }

  if (req.destination === "image" && url.href.startsWith(SCOPE_URL) && !req.headers.has("range")) {
    event.respondWith(
      staleWhileRevalidate(event, req, req).catch(() => fetch(req))
    );
  }
});
