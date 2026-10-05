const CACHE = "ciclik-shell-v1";
const SHELL = ["./", "./index.html", "./manifest.webmanifest"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => Promise.all(SHELL.map((url) => cache.add(url).catch(() => {}))))
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

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  // Only handle same-origin page navigations; Supabase/CDN/API traffic goes straight to the network.
  if (url.origin !== self.location.origin || req.mode !== "navigate") return;
  event.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok && url.pathname.replace(/\/$/, "") === "") {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put("./", copy));
        }
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match("./")))
  );
});
