"use strict";

const CACHE_NAME = "pixel-observatory-runtime-v1";
const RUNTIME_PATH = /^\/game\/runtime\/([a-zA-Z0-9._-]+)\/index\.(?:pck|wasm)$/;

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));

self.addEventListener("fetch", event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin || !RUNTIME_PATH.test(url.pathname)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request, { ignoreSearch: false });
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok) event.waitUntil(cache.put(request, response.clone()));
    return response;
  })());
});

self.addEventListener("message", event => {
  if (event.data?.type !== "pixel-observatory-runtime") return;
  const build = String(event.data.build || "").replace(/[^a-zA-Z0-9._-]/g, "");
  if (!build) return;
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_NAME);
    const requests = await cache.keys();
    await Promise.all(requests.map(request => {
      const match = new URL(request.url).pathname.match(RUNTIME_PATH);
      return match && match[1] !== build ? cache.delete(request) : Promise.resolve(false);
    }));
  })());
});
