const reducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)",
).matches;

function attachLiquidGlass(surface) {
  surface.classList.add("liquid-glass");
  const light = document.createElement("span");
  light.className = "liquid-light";
  light.setAttribute("aria-hidden", "true");
  surface.appendChild(light);

  let frame = 0;
  let targetX = surface.clientWidth * 0.5;
  let targetY = surface.clientHeight * 0.5;
  let currentX = targetX;
  let currentY = targetY;
  const settle = () => {
    currentX += (targetX - currentX) * 0.2;
    currentY += (targetY - currentY) * 0.2;
    light.style.transform = `translate3d(${currentX}px, ${currentY}px, 0)`;
    if (Math.abs(targetX - currentX) > 0.2 || Math.abs(targetY - currentY) > 0.2) {
      frame = requestAnimationFrame(settle);
    } else {
      frame = 0;
    }
  };
  surface.addEventListener("pointerenter", () => surface.classList.add("is-lit"));
  surface.addEventListener("pointermove", (event) => {
    const bounds = surface.getBoundingClientRect();
    targetX = event.clientX - bounds.left;
    targetY = event.clientY - bounds.top;
    if (!frame) frame = requestAnimationFrame(settle);
  });
  surface.addEventListener("pointerleave", () => surface.classList.remove("is-lit"));
}

if (!reducedMotion && matchMedia("(hover: hover) and (pointer: fine)").matches) {
  document.querySelectorAll(".nav-shell, .glass-panel, .journey-dialog").forEach(attachLiquidGlass);
} else {
  document.querySelectorAll(".nav-shell, .glass-panel, .journey-dialog").forEach((surface) => surface.classList.add("liquid-glass"));
}

const visitorCount = document.getElementById("visitor-count");
const visitorStorageKey = "pixel-observatory-visitor-id";
const visitorId = (() => {
  let id = localStorage.getItem(visitorStorageKey);
  if (!id) {
    id = (crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}${Math.random()}`).replace(/[^a-zA-Z0-9_-]/g, "");
    localStorage.setItem(visitorStorageKey, id);
  }
  return id;
})();
const visitorEndpoint = location.hostname.endsWith("github.io")
  ? "https://pixelobservatorygame.com/api/visits"
  : "/api/visits";
fetch(visitorEndpoint, {
  method: "POST",
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ visitorId }),
})
  .then((response) => (response.ok ? response.json() : Promise.reject()))
  .then(({ total }) => {
    const start = Number(visitorCount.textContent) || 0;
    const began = performance.now();
    const update = (now) => {
      const progress = Math.min(1, (now - began) / 600);
      visitorCount.textContent = Math.round(start + (total - start) * (1 - (1 - progress) ** 3)).toLocaleString();
      if (progress < 1) requestAnimationFrame(update);
    };
    requestAnimationFrame(update);
  })
  .catch(() => { visitorCount.textContent = "—"; });

const starfield = document.getElementById("starfield");
const starContext = starfield.getContext("2d");
let stars = [];
function resizeStarfield() {
  const dpr = window.devicePixelRatio || 1;
  starfield.width = innerWidth * dpr;
  starfield.height = innerHeight * dpr;
  starContext.setTransform(dpr, 0, 0, dpr, 0, 0);
  stars = Array.from(
    { length: Math.min(150, Math.floor(innerWidth / 10)) },
    () => ({
      x: Math.random() * innerWidth,
      y: Math.random() * innerHeight,
      radius: Math.random() * 1.2 + 0.25,
      opacity: Math.random() * 0.55 + 0.14,
    }),
  );
}
function paintStars() {
  starContext.clearRect(0, 0, innerWidth, innerHeight);
  stars.forEach((star) => {
    starContext.fillStyle = `rgba(219, 233, 237, ${star.opacity})`;
    starContext.fillRect(star.x, star.y, star.radius, star.radius);
  });
}
function resizeAndPaintStars() {
  resizeStarfield();
  paintStars();
}
resizeAndPaintStars();
let starResizeTimer;
addEventListener(
  "resize",
  () => {
    clearTimeout(starResizeTimer);
    starResizeTimer = setTimeout(resizeAndPaintStars, 120);
  },
  { passive: true },
);

const revealObserver = new IntersectionObserver(
  (entries) =>
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    }),
  { threshold: 0.14 },
);
document.querySelectorAll(".reveal").forEach((node) => {
  if (!node.classList.contains("is-visible")) revealObserver.observe(node);
});

const assemblyStage = document.querySelector("[data-assembly-stage]");
const assemblyObserver = new IntersectionObserver(
  (entries) =>
    entries.forEach((entry) => {
      if (entry.isIntersecting) assemblyStage.classList.add("is-assembled");
    }),
  { threshold: 0.38 },
);
assemblyObserver.observe(assemblyStage);

document.querySelectorAll(".view-mode").forEach((button) =>
  button.addEventListener("click", () => {
    document
      .querySelectorAll(".view-mode")
      .forEach((item) => item.classList.toggle("is-active", item === button));
    document.querySelector("[data-view-image]").dataset.mode =
      button.dataset.view;
  }),
);

const focusControl = document.querySelector(".observation-controls input");
const focusOutput = document.querySelector(".observation-controls output");
focusControl.addEventListener("input", () => {
  focusOutput.textContent = `${focusControl.value}%`;
});

const journeyRail = document.querySelector("[data-journey-rail]");
const journeySlides = [...document.querySelectorAll(".journey-slide")];
const selectJourneySlide = (selected) => {
  journeySlides.forEach((slide) =>
    slide.classList.toggle("is-selected", slide === selected),
  );
};
const journeyObserver = new IntersectionObserver(
  (entries) => {
    const centered = entries
      .filter((entry) => entry.isIntersecting)
      .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
    if (centered) selectJourneySlide(centered.target);
  },
  { root: journeyRail, threshold: [0.55, 0.75] },
);
journeySlides.forEach((slide) => {
  journeyObserver.observe(slide);
  slide.addEventListener("click", () => selectJourneySlide(slide));
});

const journeyDialog = document.getElementById("journey-dialog");
document
  .querySelectorAll("[data-open-journey]")
  .forEach((button) =>
    button.addEventListener("click", () => journeyDialog.showModal()),
  );
document
  .querySelector("[data-close-dialog]")
  .addEventListener("click", () => journeyDialog.close());
journeyDialog.addEventListener("click", (event) => {
  if (event.target === journeyDialog) journeyDialog.close();
});
