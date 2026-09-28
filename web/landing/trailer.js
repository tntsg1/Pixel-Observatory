// Official trailer player for the landing page.
//  idle   → poster + play button
//  teaser → muted 10 s loop while the frame is on screen (skipped for reduced
//           motion / Save-Data)
//  full   → the 2-minute trailer with sound, custom controls
//  ended  → end screen that hands the visitor straight to the game
(function () {
	"use strict";
	var VERSION = "20260927";
	var BASE = "/media/trailer/" + VERSION + "/";

	var frame = document.getElementById("trFrame");
	var video = document.getElementById("trVideo");
	if (!frame || !video) return;
	var playBtn = document.getElementById("trPlay");
	var toggleBtn = document.getElementById("trToggle");
	var muteBtn = document.getElementById("trMute");
	var fsBtn = document.getElementById("trFs");
	var seek = document.getElementById("trSeek");
	var time = document.getElementById("trTime");
	var replayBtn = document.getElementById("trReplay");

	var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
	var conn = navigator.connection || {};
	var saveData = !!conn.saveData || /(^|-)2g$/.test(conn.effectiveType || "");
	var narrow = (window.innerWidth || document.documentElement.clientWidth || 0) < 900;
	var fullSrc = BASE + (narrow || saveData ? "trailer-720.mp4" : "trailer-1080.mp4");
	var teaserSrc = BASE + "teaser-720.mp4";

	var mode = "idle";
	var autoPaused = false;
	var uiTimer = 0;

	var ICON_PLAY = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2l10 6-10 6z"/></svg>';
	var ICON_PAUSE = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M3 2h4v12H3zM9 2h4v12H9z"/></svg>';
	var ICON_SOUND = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6h3l4-3v10L5 10H2z"/><path d="M11 5.2a4 4 0 0 1 0 5.6l-.9-.9a2.7 2.7 0 0 0 0-3.8z"/></svg>';
	var ICON_MUTED = '<svg viewBox="0 0 16 16" aria-hidden="true"><path d="M2 6h3l4-3v10L5 10H2z"/><path d="M11 6l1 1 1-1 1 1-1 1 1 1-1 1-1-1-1 1-1-1 1-1-1-1z"/></svg>';

	function setState(state) {
		mode = state;
		frame.setAttribute("data-state", state);
	}

	function fmt(t) {
		t = Math.max(0, Math.floor(t || 0));
		return Math.floor(t / 60) + ":" + ("0" + (t % 60)).slice(-2);
	}

	function syncControls() {
		var paused = video.paused;
		frame.classList.toggle("is-paused", mode === "full" && paused);
		toggleBtn.innerHTML = paused ? ICON_PLAY : ICON_PAUSE;
		toggleBtn.setAttribute("aria-label", paused ? "Play" : "Pause");
		muteBtn.innerHTML = video.muted ? ICON_MUTED : ICON_SOUND;
		muteBtn.setAttribute("aria-label", video.muted ? "Unmute" : "Mute");
	}

	function syncTime() {
		if (mode !== "full") return;
		var d = video.duration || 120;
		var p = (video.currentTime / d) * 100;
		seek.value = String(p);
		seek.style.setProperty("--p", p + "%");
		time.textContent = fmt(video.currentTime) + " / " + fmt(d);
	}

	function wakeUi() {
		frame.classList.add("show-ui");
		clearTimeout(uiTimer);
		uiTimer = setTimeout(function () { frame.classList.remove("show-ui"); }, 2200);
	}

	function playSafely() {
		var p = video.play();
		if (p && p.catch) {
			p.catch(function () {
				// Autoplay with sound refused: keep going muted rather than stall.
				if (!video.muted) {
					video.muted = true;
					video.play().catch(function () {});
					syncControls();
				}
			});
		}
	}

	function startFull() {
		autoPaused = false;
		frame.classList.add("is-switching");
		video.loop = false;
		video.muted = false;
		if (video.getAttribute("src") !== fullSrc) {
			video.src = fullSrc;
			video.preload = "auto";
		}
		setState("full");
		try { video.currentTime = 0; } catch (e) { /* metadata not loaded yet */ }
		playSafely();
		wakeUi();
		syncControls();
	}

	video.addEventListener("playing", function () {
		frame.classList.remove("is-switching");
		syncControls();
	});
	video.addEventListener("pause", syncControls);
	video.addEventListener("volumechange", syncControls);
	video.addEventListener("timeupdate", syncTime);
	video.addEventListener("loadedmetadata", syncTime);
	video.addEventListener("ended", function () {
		if (mode !== "full") return;
		setState("ended");
		frame.classList.remove("is-paused");
		if (document.fullscreenElement === frame && document.exitFullscreen) document.exitFullscreen().catch(function () {});
		var cta = document.getElementById("trEndPlay");
		if (cta) cta.focus({ preventScroll: true });
	});

	playBtn.addEventListener("click", startFull);
	replayBtn.addEventListener("click", startFull);
	toggleBtn.addEventListener("click", function () {
		if (video.paused) playSafely(); else video.pause();
		autoPaused = false;
	});
	video.addEventListener("click", function () {
		if (mode !== "full") return;
		if (video.paused) playSafely(); else video.pause();
		autoPaused = false;
		wakeUi();
	});
	muteBtn.addEventListener("click", function () {
		video.muted = !video.muted;
		syncControls();
	});
	fsBtn.addEventListener("click", function () {
		if (document.fullscreenElement) { document.exitFullscreen().catch(function () {}); return; }
		if (frame.requestFullscreen) frame.requestFullscreen().catch(function () {});
		else if (video.webkitEnterFullscreen) video.webkitEnterFullscreen();
	});
	seek.addEventListener("input", function () {
		var d = video.duration || 120;
		video.currentTime = (parseFloat(seek.value) / 100) * d;
		seek.style.setProperty("--p", seek.value + "%");
		wakeUi();
	});
	frame.addEventListener("mousemove", function () { if (mode === "full") wakeUi(); });
	frame.addEventListener("keydown", function (e) {
		if (mode !== "full") return;
		if (e.target === seek) return;
		if (e.key === " " || e.key === "k" || e.key === "K") {
			e.preventDefault();
			if (video.paused) playSafely(); else video.pause();
		} else if (e.key === "m" || e.key === "M") {
			video.muted = !video.muted;
		} else if (e.key === "ArrowRight") {
			video.currentTime = Math.min((video.duration || 120) - 0.1, video.currentTime + 5);
		} else if (e.key === "ArrowLeft") {
			video.currentTime = Math.max(0, video.currentTime - 5);
		} else {
			return;
		}
		wakeUi();
	});

	// "Watch the trailer" buttons elsewhere on the page glide here and start with sound.
	Array.prototype.forEach.call(document.querySelectorAll("[data-trailer-open]"), function (el) {
		el.addEventListener("click", function (e) {
			e.preventDefault();
			frame.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "center" });
			startFull();
		});
	});

	// Teaser loop only while the frame is on screen; full playback pauses when
	// scrolled away and resumes when the visitor comes back.
	if ("IntersectionObserver" in window) {
		var io = new IntersectionObserver(function (entries) {
			entries.forEach(function (entry) {
				var visible = entry.isIntersecting && entry.intersectionRatio >= 0.35;
				if (mode === "idle" && visible && !reduceMotion && !saveData) {
					video.muted = true;
					video.loop = true;
					video.src = teaserSrc;
					setState("teaser");
					playSafely();
				} else if (mode === "teaser") {
					if (visible) playSafely(); else video.pause();
				} else if (mode === "full") {
					if (!visible && !video.paused) { autoPaused = true; video.pause(); }
					else if (visible && autoPaused) { autoPaused = false; playSafely(); }
				}
			});
		}, { threshold: [0, 0.35, 0.6] });
		io.observe(frame);
	}

	document.addEventListener("visibilitychange", function () {
		if (document.hidden && mode === "teaser") video.pause();
	});

	syncControls();
})();
