"use strict";

importScripts("/game-runtime-core.js");

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));

self.addEventListener("fetch", event => {
  const request = event.request;
  if (!self.PORuntimeCache?.matchesRuntime(request)) return;
  event.respondWith(self.PORuntimeCache.runtimeResponse(request, {
    fetcher: fetch,
    onProgress: detail => self.clients.matchAll({ type: "window", includeUncontrolled: true })
      .then(clients => clients.forEach(client => client.postMessage(detail))),
  }));
});

self.addEventListener("message", event => {
  if (event.data?.type !== "pixel-observatory-runtime") return;
  const build = String(event.data.build || "").replace(/[^a-zA-Z0-9._-]/g, "");
  if (!build) return;
	const packs = event.data.packs && typeof event.data.packs === "object" ? event.data.packs : {};
  event.waitUntil((async () => {
    await self.PORuntimeCache?.prune(build, packs);
  })());
});
