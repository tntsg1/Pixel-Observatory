(() => {
  "use strict";

  const build = document.documentElement.dataset.pixelObservatoryBuild || "unknown";
  const cacheName = "pixel-observatory-runtime-v1";
  const runtimePath = /^\/game\/runtime\/[a-zA-Z0-9._-]+\/index\.(?:pck|wasm)$/;

  // The service worker cannot control the document that first installs it.
  // Cache the initial Godot fetches here so the very next visit is already warm.
  if ("caches" in window && !window.__pixelObservatoryRuntimeFetchInstalled) {
    window.__pixelObservatoryRuntimeFetchInstalled = true;
    const nativeFetch = window.fetch.bind(window);
    window.fetch = async (input, init) => {
      const request = new Request(input, init);
      const url = new URL(request.url);
      if (request.method !== "GET" || url.origin !== location.origin || !runtimePath.test(url.pathname)) {
        return nativeFetch(input, init);
      }
      const cache = await caches.open(cacheName);
      const cached = await cache.match(request);
      if (cached) return cached;
      const response = await nativeFetch(request);
      if (response.ok) cache.put(request, response.clone()).catch(() => {});
      return response;
    };
  }

  if (!("serviceWorker" in navigator) || !window.isSecureContext) return;

  const workerUrl = `/game-cache-sw.js?build=${encodeURIComponent(build)}`;

  navigator.serviceWorker.register(workerUrl, { scope: "/game/" })
    .then(async registration => {
      if (navigator.storage?.persist) {
        try { await navigator.storage.persist(); } catch (_) {}
      }
      const worker = registration.active || registration.waiting || registration.installing;
      worker?.postMessage({ type: "pixel-observatory-runtime", build });
    })
    .catch(error => console.warn("Runtime cache registration failed", error));
})();
