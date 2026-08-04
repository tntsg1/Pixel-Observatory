(() => {
  "use strict";

  const build = document.documentElement.dataset.pixelObservatoryBuild || "unknown";
  const runtime = window.PORuntimeCache;
  if (!runtime) {
    console.warn("Runtime resume cache core did not load.");
    return;
  }

  const emitProgress = detail => {
    window.dispatchEvent(new CustomEvent("po:runtime-progress", { detail }));
  };

  // The service worker cannot control the document that first installs it.
  // Intercepting fetch here gives that first launch the same resumable ranges
  // as later launches. Finished chunks are persisted before they reach Godot.
  if ("caches" in window && !window.__pixelObservatoryRuntimeFetchInstalled) {
    window.__pixelObservatoryRuntimeFetchInstalled = true;
    const nativeFetch = window.fetch.bind(window);
    window.fetch = async (input, init) => {
      const request = new Request(input, init);
      if (!runtime.matchesRuntime(request)) return nativeFetch(input, init);
      return runtime.runtimeResponse(request, { fetcher: nativeFetch, onProgress: emitProgress });
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
