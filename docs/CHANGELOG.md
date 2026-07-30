# Pixel Observatory Changelog

This is the English-first release log for Pixel Observatory. It restores the
major project history that was previously summarized too aggressively in the
README. Earlier records remain preserved in [`VERSION_HISTORY.md`](VERSION_HISTORY.md),
which contains the detailed target/function/fix/verification format. This file
adds a readable release-facing timeline with dates, player-facing meaning and
concrete implementation details.

## How To Read This Log

- The early `v0.x` and `v1.x` labels are historical development milestones.
- A milestone can describe a system that was later refined; it does not mean
  that every later visual or content issue disappeared permanently.
- Advanced telescope families are described as framework, active development or
  finished only where that distinction is explicit.
- The public Web build is updated only after source changes are exported and
  deployed by the workflow.

## 2026-07-29 - Deliberate Community and Account Dismissal

**Safer modal tasks:** Clicking the dimmed area around Community, sign-in or
account creation no longer closes the active surface. This prevents an
imprecise desktop or touch click from discarding navigation context or typed
registration details. Players still retain predictable explicit exits through
the visible close button and Escape key.

## 2026-07-29 - FAST Active Pulse Capture

**Playable confirmation:** FAST stage 4 no longer asks the observer to hold a
receiver key or wait for passive stability windows. After period, DM and phase
alignment, a visible phase gate sweeps the folded two-cycle profile. The player
short-presses Space or the matching capture button three times as the recovered
primary pulse crosses the gate; each capture freezes the trace briefly, grows
SNR and the folded profile, records a terminal packet, and the third capture
immediately starts the existing pulse-lock handoff.

**Recovery and access:** Early and late taps show signed millisecond guidance
without erasing progress. Key repeat, long presses and focus-loss cannot create
extra or stuck captures. The Settings panel includes an optional wider capture
window, while retaining all three deliberate captures. The same measured
period, DM, pulse width, SNR, confidence, sky position and source model flow
unchanged into the lock, report and saved FAST archive.

## 2026-07-29 - FAST Pulsar Recovery Rework

**Discovery loop:** FAST's fourth observation stage is now a continuous radio
analysis sequence rather than a short series of +/- adjustments. Observers
scan a correlation belt for a repeating clock, drag seven sub-band tracks into
dispersion alignment, rotate a phase-folding ring and monitor a brief clock
drift correction while a two-peak pulse profile emerges from noise. Each
control changes its linked trace, correlation, peak shape or SNR immediately;
an incorrect alias cannot complete the observation and a small correction no
longer discards all prior progress.

**Scientific handoff:** The successful lock freezes the recovered pulse,
prints measured period, DM, pulse width, SNR, confidence, sky position and
candidate model, then carries that same measurement packet into the report and
saved radio-observation archive. The journal now reconstructs a compact
dedispersed-spectrum and folded-double-peak thumbnail from that saved packet,
for both campaign and free-observation records. FAST's onboarding now explains
that this is a radio timing observation, not a visible-light photograph. The
data-only motion respects the project's reduced-motion option and uses the
existing licensed/original FAST cues without adding music.

## 2026-07-29 - Observatory Reliability and Remote Instrument Update

**Progress and language:** Starting a campaign now preserves the language
chosen on the main menu, including a first Chinese-language playthrough. The
menu shows Continue only for a parseable, initialized save with resumable
progress; empty, malformed and incomplete archives safely fall back to New
Game. Browser cloud restoration waits for the signed-in account's archive, so
one observer's local progress cannot briefly appear for another observer.

**Remote observatories:** Signed-in playtime now uses foreground-only heartbeat
leases so duplicate tabs and refreshes do not inflate leaderboard time. Space
Infrared campaign assembly retains its documented four required commissioning
parts while unlocked modules remain usable; graduation enables full free-build
auto assembly in dependency order.

**Observatory floor:** The lower-right remote-instrument terminal now uses the
approved transparent desk asset with nearest-neighbour rendering, fitting
collision footprints, reachability checks and correct actor occlusion. It
retains its FAST and Space Infrared control interaction.

**Web community:** Observer friend messaging adds real-time direct-message
drawers with server-side friendship checks, text-only rendering and retained
drafts after a failed send. The public site also documents the environment
simulation chapter in English and Chinese.

**Web launch and timing:** `/game/` now remains a Pixel Observatory launch
shell after every export: Godot runtime files are staged under a private export
directory, while the public game entrypoint supplies the deep-space progress
sequence, reduced-motion behavior, game-adjacent observer rails, friend
actions and field-report dock. Static release assets never contain a PCK;
runtime PCK/WASM delivery remains on the game-asset route. Playtime reports are
idempotent across a lost response, so an acknowledged heartbeat cannot be
credited twice on retry.

## 2026-07-28 - Observatory Accounts and Field Reports

**Delivered:** The canonical website now supports observer accounts with
username/password registration, secure browser sessions and automatic cloud
progress sync for the Godot Web build. Local saves remain authoritative while
offline, and an older cloud save cannot silently erase more advanced local
progress.

**Feedback:** Players can transmit categorized field reports from any page.
Every accepted report receives a visible observatory receipt, while the
developer-only console can filter reports, add private notes and move them
through new, reviewing, planned, resolved and closed states.

**Security:** Registration and feedback use Cloudflare Turnstile plus a hidden
honeypot and D1-backed rate limits. Passwords use salted PBKDF2-SHA256 hashes;
sessions are stored as hashes and delivered only through Secure, HttpOnly,
SameSite cookies. Raw visitor addresses are never stored in rate-limit records.

## 2026-07-27 - Independent Observer Release

**Delivered:** Graduation is now a four-part playable closing sequence: course
recap, observing archive, optical-equipment handover and the first independent
night. Completed and unlocked optical telescope families become the player's
owned equipment, while Space Infrared and FAST remain remote research
facilities.

**Fixed:** The central observatory pad now reads a persistent
`active_optical_telescope_id`. Completing or editing an optical build equips
that family, and visiting FAST or Space Infrared no longer overwrites it or
redirects local optical observing into a remote facility.

**Also included:** The FAST science-product and mission-complete presentation
now use radio evidence rather than optical result language. Both unapproved
remote-observatory music resources and the undocumented FAST terminal ambience
were removed. Space Infrared and all FAST levels now use an explicit silent
music route until licensed replacements are supplied.

**Verified:** Graduation, old-save migration, local optical routing after both
remote facilities, FAST result binding and headless Godot 4.7 compilation have
focused automated coverage. The release includes 1024x768 English and Chinese
captures for the new graduation and equipment-routing states.

## Historical Milestones

### v0.1 — Project Replacement and MVP Foundation

**Purpose:** Replace the former prototype with a 2D pixel astronomy teaching
game and establish a runnable loop.

**Delivered:** The project became Pixel Observatory with a Main Menu, Observatory
Room, Telescope Assembly, Sky Observation, Telescope View, Learning Card and
Learning Journal. Core managers were established for saves, missions, assembly,
telescope math and observation evaluation. Levels, parts, celestial objects and
localization moved into JSON data.

**Why it mattered:** The project stopped being a generic technical prototype and
became a playable astronomy-learning product with a clear educational subject.

### v0.2 — Movable Observatory Room

**Purpose:** Turn the flow into an explorable base instead of a page of buttons.

**Delivered:** A movable player, WASD/arrow movement, proximity interaction,
Mission Board, Parts Cabinet, Assembly Table, Observatory Door, Telescope Pad,
Learning Journal and Stats Terminal. The HUD began showing level, credits,
telescope state and nearby interaction guidance.

**Known lesson:** Early workshop/furniture assets were visually inconsistent,
which motivated the later complete-background approach.

### v0.3 — Observatory Interior Redesign

**Purpose:** Establish a believable astronomy-club room and clearer routes.

**Delivered:** The base was redesigned around a school astronomy club, with a
door and observation pad as meaningful destinations. Missing telescope parts
directed the player to the Assembly Table; a completed telescope directed the
player toward observation.

**Player effect:** The base became part of the story and not just a decorative
background.

### v0.4 — Playable Telescope Assembly

**Purpose:** Replace debug-style installation with a readable assembly activity.

**Delivered:** The three-column Parts Tray / Blueprint / Inspector layout,
select-part-then-snap-slot interaction, installation order, wrong-slot feedback,
wrong-attempt tracking and Finish Assembly validation. Installed state began
reading from `assembly_state` instead of incorrectly treating unlocked parts as
installed.

### v0.5 — First Complete Mission Loop

**Purpose:** Prove that a player can start, observe, identify, learn and progress.

**Delivered:** New Game began with an unassembled telescope. The first Moon
mission could be selected in Sky Observation, identified in Telescope View,
recorded in the Learning Journal, rewarded with credits and followed by the next
level.

### v0.6 — Distinct Sky Observation Targets

**Purpose:** Make the sky feel like an astronomy scene rather than a button list.

**Delivered:** Moon, Polaris, Sirius, Betelgeuse, Mars, Jupiter, Orion Nebula
and Andromeda received distinct visual treatment. Transparent click regions kept
the starfield visible, while selection used a gold highlight rather than a large
opaque rectangle.

### v0.7 — Telescope View and Quality States

**Purpose:** Separate “what the player sees” from “what the player identifies.”

**Delivered:** A circular telescope field, target-specific images, Excellent/Good/
Fair/Poor/Failed quality states, and identification choices. Incorrect answers
could be rejected without completing the mission.

### v0.8 — Parts Cabinet and Assembly Separation

**Purpose:** Fix the information architecture so inventory and assembly do not
become one confusing screen.

**Delivered:** Parts Cabinet became an inventory/description screen while the
Assembly Table became the installation screen. Part mappings, return routes and
post-assembly guidance were clarified.

### v0.9 — Complete Observatory Background

**Purpose:** Stabilize the visual composition using a complete background image.

**Delivered:** The room used one coherent background with the player, transparent
interaction layer and HUD rendered above it. Interaction boxes were tightened
around the actual furniture and the player sprite gained separate display and
collision sizing with a stable foot anchor.

### v1.0 — Four-Direction Player Animation

**Purpose:** Fix wrong-facing sprites, frame bleeding, head remnants and foot
position drift.

**Delivered:** A clean 4-column by 4-row player sheet with down, left, right and
up rows; idle and walking frames; direction-aware animation; separate visual and
collision dimensions; and a shared bottom-foot anchor.

### v1.1 — Real Sky Position Pipeline

**Purpose:** Move the sky from invented fixed positions toward location-aware
observation.

**Delivered:** `SkyPositionService`, catalog data and observing configuration.
Solar-system targets could use AstronomyAPI when configured; stars and deep-sky
objects used RA/Dec calculations; offline/local fallback paths were retained.
Secrets were moved out of scripts and kept in ignored local configuration.

### v1.2 — Teaching Before Operation

**Purpose:** Put explanations before the player needs a new skill.

**Delivered:** `TeachingFlowManager`, Concept Briefs, one-time teaching steps,
separate “seen” and “completed” records, and operation-specific triggers for
assembly, observation, focus, identification and collimation.

### v1.3 — Focus Knob as a Real Part

**Purpose:** Make focus control depend on an installed component.

**Delivered:** Basic Focus Knob data, an assembly slot near the eyepiece,
`focus_control_score`, DMS coordinate feedback, and a clear gate when the part
was not installed.

### v1.4 — Readable Learning Card Diagrams

**Purpose:** Make the visual explanation large enough to teach from.

**Delivered:** Enlarged Concept Brief and Mission Complete diagram areas,
aspect-ratio-preserving TextureRect behavior and nearest-neighbour rendering for
optical paths, focal planes and observation concepts.

### v1.5 — Orion Nebula Focus and Quality Pass

**Purpose:** Prevent players from mistaking poor equipment quality for failed
focus.

**Delivered:** A more forgiving early Orion Nebula lesson, separate focus and
quality feedback, and clearer guidance for the difference between “focus is
wrong” and “the equipment/conditions are limiting the image.”

### v1.6 — Starlight Observatory Main Menu

**Purpose:** Replace the minimal menu with a recognizable product identity.

**Delivered:** A complete observatory-at-night main-menu background and
New Game, Continue, Settings, Language and Quit actions with pixel-realistic
brass/navy styling.

### v1.7 — Unified Eye / Finder / Scope Mode UI

**Purpose:** Make the three observation stages visually consistent.

**Delivered:** Shared mode-button artwork, transparent hit areas, active-state
framing and unavailable/inactive states that no longer compete visually.

### v1.8 — Jupiter Observation States

**Purpose:** Make observation quality visible instead of only numerical.

**Delivered:** Clear, blurry and dim Jupiter states, with quality results mapped
to the appropriate visual state and a large-image fallback for the Telescope View.

### v1.9 — Advanced Telescope Framework and Observation HUD

**Development period:** 2026-07-19.

**Purpose:** Integrate advanced assembly, optical feedback, environmental effects,
first-use guidance, target locking and a richer coordinate HUD.

**Delivered:**

- Newtonian and nested optical-tube assembly scaffolding.
- Newtonian collimation with an optical-axis result and threshold feedback.
- Refractor chromatic-aberration motivation and later reflector comparison.
- Real transparent installed-part textures with layer order:
  blueprint → installed art → completion border → OK marker → click region.
- Interaction feedback for hover, press, success, error, snapping and page entry.
- Focus, seeing, clouds, drift, tracking, finder calibration and target-lock
  feedback paths.
- Top azimuth and left altitude scales with DMS values.
- Eye, Finder and Scope reticle assets and shared target-derived lock radii.
- Identification feature guidance before the answer choices and randomized
  answer placement.
- Reduced-motion support so important state changes remain visible without large
  animation.

**Validation:** Observation UI acceptance, reticle regression, Newtonian parity,
modal-layer, coordinate-lock, animation-feedback, environmental-effect,
assembly-texture, story, teaching and full-flow suites were reported as passing.

### v2.0 — Web Delivery and Mobile Input

**Development period:** 2026-07-19 to 2026-07-20.

**Purpose:** Make the game playable through the public website and prepare a
mobile-style input path.

**Delivered:**

- Godot Web export through GitHub Actions and GitHub Pages.
- Custom-domain delivery at `pixelobservatorygame.com` with Cloudflare in the
  delivery layer.
- Mobile Controller Mode with virtual joystick, interaction button, mission
  button, scope switching, focus controls and collimation controls.
- Touch-input abstraction that keeps the desktop keyboard path intact.
- Initial mobile observation gestures and touch-safe UI sizing.
- World-location, horizon, free-observation and detailed target-panel framework.

**Known follow-up:** Web deployment and mobile input still require real-device
testing across aspect ratios, and the world-map/horizon presentation needs more
cinematic polish and clearer first-use explanation.

## Dated Recent Updates

### 2026-07-25 — Official Landing Page Rebuild

- Replaced the landing source with a new official website built around the
  game's own artwork: the observatory hero scene, the exploded refractor, the
  workshop bench, the observation console, and eight individual instrument
  plates instead of one combined sheet.
- Structured the page as chapters covering assembly, optics, the limits of
  glass, the three observation modes, the living sky, the instrument path, how
  the Newtonian, Dobsonian, infrared space and radio designs actually work,
  what distinguishes the project, and the current development status.
- Checked every quantitative claim against project data: active campaign
  length, part and telescope-family counts, catalogued star totals, Concept
  Brief and skill-tutorial counts, observing sites, and the optical and
  atmospheric limits enforced by the observation system.
- Kept the site English-first with a Chinese toggle, and pointed every play
  action at the relative same-origin `game/` route.
- Preserved the anonymous Cloudflare visitor counter, canonical URL, Open Graph
  and Twitter cards, theme colour, structured data and favicon. Added `CNAME`,
  `robots.txt` and `sitemap.xml` to the published root.
- Rewrote `tools/import_user_landing.mjs` so every transform is asserted. A
  replacement that no longer matches the authored source now fails the import
  instead of publishing the page without that feature; the previous version
  would have silently dropped the navigation animation and mis-aligned the
  bilingual tooltip column. Tooltips are now keyed by their authored text
  rather than by position.

### 2026-07-25 - Canonical Website and Game Route

- Corrected the custom-domain release structure so
  `pixelobservatorygame.com/` serves the official Starlight Observatory website
  and its play actions open the game at the same-origin `/game/` route.
- Kept GitHub Pages as a deployment mirror instead of exposing its repository
  subpath as the player-facing destination.
- Added Cloudflare R2 routing for the large Godot pack and side-module files
  requested from `/game/`.

### 2026-07-25 — Advanced Observatory Interaction, Narrative and Accessibility Pass

- Expanded the advanced-observatory campaign data, Maya dialogue revisions and
  telescope heritage records so instruments have a clearer historical and
  narrative context instead of appearing as isolated technical unlocks.
- Added tutorial-assistance controls so players can choose full guidance,
  lighter prompts or freer exploration without breaking mission progression.
- Strengthened space infrared operations with target-aware attitude slewing,
  thermal constraints, interactive wavefront alignment and evidence-based
  false-colour channel mapping.
- Upgraded the FAST radio-observation model and five-stage flow: feed-cabin
  inertia and braking, receiver-window tuning, distinct RFI classes, period and
  dispersion-measure alignment, sustained integration, and evidence-gated radio
  reports. The ongoing CRT presentation pass is intentionally not listed here
  as complete until its visual review is finished.
- Added a small, replaceable core SFX foundation and event routing for assembly,
  focus, target locking, space operations and FAST actions, together with an
  in-game SFX preference. These bundled sounds are implementation placeholders
  pending a final real-world foley/audio asset pass.
- Added focused headless checks, capture tools and regression coverage for the
  new observation, teaching, localization and accessibility paths.
- Reworked the browser delivery shell so the web build opens on a branded,
  responsive Pixel Observatory start screen before revealing the Godot canvas.
  Added an anonymous, refresh-safe Cloudflare visitor counter backed by a
  Durable Object, plus deployment-time shell generation for every Web export.
- Replaced the temporary Web-export overlay with the project's dedicated
  astronomy-site landing experience and moved the Godot build to `/game/`.
  Web exports now disable desktop VRAM texture compression because it caused
  browser `CompressedTexture2D` loader failures and greyed-out main-menu and
  observatory-platform imagery.

### 2026-07-04 — L10-L24 Teaching and Practice Structure

- Designed a spiral practice structure so one concept could be revisited across
  several missions with different conditions.
- Added chapter-level reasons for repeated targets, including focus,
  magnification, finder navigation, light gathering and tracking.
- Added teaching/story/mission-board data for the expanded early campaign.
- Recorded remaining gaps where data fields existed but mechanics still needed
  to be connected.

### 2026-07-05 — Observation Effects Specification

- Documented the intended relationship between focus, seeing, clouds, brightness,
  drift, magnification and tracking.
- Defined the difference between focus failure and insufficient observation
  quality so feedback would not blame the wrong mechanic.
- Identified the need for distinct clear, blurry and dim target artwork.

### 2026-07-10 to 2026-07-12 — Newtonian and Advanced Assembly Work

- Added reflector-family data and the nested optical-tube concept.
- Added main blueprint and tube blueprint workflows.
- Added primary mirror, mirror cell, secondary spider, secondary mirror,
  focuser, eyepiece and collimation-tool slots.
- Reused compatible tripod, mount and finder components outside the central tube
  assembly, matching the refractor information architecture.
- Added installed-art rendering, slot alignment checks and family-aware part
  filtering.

### 2026-07-18 — Observation HUD and Target Feedback

- Added or refined reticle assets for naked eye, finder and telescope views.
- Unified target projection, approach ring, lock ring, click region and actual
  completion radius.
- Refined coordinate bands, pointer behavior, focus controls and target guidance.
- Added stronger visual feedback for collimation, tracking, cloud effects and
  target-centered state.

### 2026-07-19 — Web Publishing and Project Archive

- Archived the active project state and published the Web export workflow.
- Added Cloudflare/GitHub Pages deployment documentation and the public domain.
- Updated the English-first project overview and historical documentation.

### 2026-07-20 — Location, Horizon and Free Observation Systems

- Added the framework for observing-site selection when a target is below the
  horizon.
- Added world-map/location transition data and layered horizon scenery.
- Added free observation so non-mission celestial objects can be selected,
  inspected in a detailed scrollable panel and recorded without advancing the
  mission.
- Added online/local/offline data-source status so the origin of a coordinate is
  visible to the player.

### 2026-07-22 — Learning Diagram and Mobile Cabinet Update

- Replaced the `naked_eye_limits` teaching image with a larger light-gathering
  diagram showing pupil size, aperture, collected light and faint objects.
- Enlarged the Concept Brief image area while preserving its source ratio and
  nearest-neighbour pixel rendering.
- Added touch swipe scrolling to the Parts Cabinet.
- Added tap-versus-drag separation so a vertical swipe does not accidentally
  equip a part or open another screen.
- Preserved desktop mouse-wheel scrolling and normal click behavior.
- Added focused regression tests and capture checks for both changes.

## Current Known Gaps

These are intentionally listed so the log does not imply that every framework
feature is already a polished 1.0 feature:

- Some advanced telescope families still need final artwork, blueprint polish
  and family-specific interaction.
- Some later campaign content needs a diversity pass to avoid repeating the
  same target or concept card too many times.
- Below-horizon travel needs a stronger transition animation, clear world-map
  controls and more convincing parallax horizon layers.
- Mobile controls need real Android testing and a final APK release process.
- Some live astronomy data can fall back to local calculations or offline
  estimates when an external service is unavailable.

## Release Verification Policy

Before a release, run the relevant Godot headless tests, preserve/restore the
real save file, inspect 1024x768 and mobile captures, verify that no new UI text
mixes languages, and confirm that the Web export workflow completes. A source
commit is not itself a Web release until the export and deployment jobs finish.
