# Pixel Observatory

**Pixel Observatory** is a pixel-realistic astronomy education game made with
Godot 4.7. It turns the process of learning astronomy into a playable story:
the player joins a school astronomy club, learns from Maya, assembles optical
equipment, navigates the night sky, observes real celestial targets, and keeps
an evolving Club Logbook.

> **Build a telescope. Learn the sky. Make the observation yourself.**

This project is designed to be more than a static star map, a worksheet, or a
collection of astronomy facts. The player must understand an idea and then use
it: find a target, choose compatible equipment, assemble the instrument, aim
through several optical views, focus the image, respond to the observing
conditions, and identify what was actually seen.

## Why This Project Is Different

Most astronomy education projects are either tabletop activities, reference
tools, planetarium viewers, or static visualizations. Pixel Observatory combines
those learning goals with a complete digital game loop:

- **A game rather than a reference screen.** The player has missions, rewards,
  equipment decisions, failure states, progression, and a reason to keep
  observing.
- **Hands-on instrument reasoning.** Parts are not decorative inventory items.
  A mount affects stability, an eyepiece changes magnification and field of
  view, a focus control enables precise focusing, and a finder scope changes how
  a player searches for a target.
- **A staged observation process.** The player moves from naked-eye direction
  finding to finder-scope alignment and then to the narrow telescope field.
- **Environmental consequences.** Focus error, aperture, magnification, seeing,
  clouds, light pollution, tracking, drift, dark adaptation, and target
  brightness can change the image and the quality result.
- **An AI-style mentor layer.** Maya introduces concepts, explains why a new
  instrument is needed, gives first-use guidance, and connects a technical
  result back to the story.
- **A progression and competition layer.** Club Credits, observation quality,
  badges, repeatable practice, equipment unlocks, and logbook completion turn
  scientific practice into a measurable game journey.

The project can therefore act both as an educational game prototype and as a
research/presentation artifact that demonstrates how astronomy learning can be
embedded in interactive digital play.

## Player Experience

The central loop is deliberately simple to understand but deep enough to
reward practice:

```text
Join the Astronomy Club
        ↓
Read the mission and Maya's guidance
        ↓
Choose a telescope family and compatible equipment
        ↓
Assemble the telescope and its optical tube
        ↓
Navigate the sky with naked eye → finder → telescope
        ↓
Adjust focus, magnification, alignment and tracking
        ↓
Observe the target and identify it
        ↓
Review quality, rewards and the concept learned
        ↓
Record the result in the Club Logbook and unlock the next lesson
```

## Main Gameplay Systems

### Observatory Base

The Observatory Room is the player's home base. It contains the Mission Board,
Parts Cabinet, Assembly Table, Telescope Observation Pad, Observatory Door,
Learning Journal and Stats Terminal. The player moves through the room and
interacts from the correct position, while the current objective is shown with
contextual guidance and a highlighted target. The room is intentionally a
playable space rather than a menu hub: the player learns where equipment is
stored, where instruments are assembled, and where observations begin.

### Story and Teaching Flow

Maya's story is connected to the player's actions. New Game introduces the club
and the observatory; first-use events explain the next instrument or technique;
mission completion provides a short scientific recap. `StoryManager` handles
story events and `TeachingFlowManager` handles Concept Briefs so that:

- a first-use explanation appears before the player must perform the action;
- story, teaching, completion and logbook records remain separate;
- a lesson is not repeatedly shown just because a player revisits a scene;
- the return route preserves the target, level and observation context;
- the current task is shown in the Mission Board and in the room guidance.

The intended teaching pattern is **explain first, demonstrate second, practice
again with a changed condition**. A later mission may revisit the same concept,
but it should change the target, equipment, environment, or decision rather than
replay identical text.

### Parts Cabinet and Telescope Selection

The Parts Cabinet is an inventory and equipment-selection screen, separate from
the Assembly Table. It supports telescope-family filters, compatible-part
recommendations, unlocked/equipped status, and mobile touch scrolling. The
planned selection model lets the player choose a telescope family first, then
see the parts compatible with that family. A recommended loadout can select the
strongest compatible objective, eyepiece, mount and control parts available for
the current lesson without mixing incompatible families.

The cabinet is not the assembly table. It answers **“what equipment do I own
and want to use?”** The assembly table answers **“where does each selected part
go, and is the instrument physically complete?”**

### Telescope Assembly

The main assembly screen uses a three-column structure:

1. **Parts Tray** for selectable components.
2. **Blueprint** for snap slots and the instrument structure.
3. **Inspector** for status, statistics, hints, requirements and completion.

The refractor and reflector families share the same outer assembly idea:
tripod/base, mount, optical tube assembly and finder scope are installed at the
main level. A complex optical tube can open a nested sub-assembly where the
player installs the internal optical parts. Installed parts use real transparent
pixel-art images, completed slots show the installed artwork and completion
state, and the player can enable assembly hints to see the next required part
and why it belongs there.

### Three Observation Views

The Sky Observation screen is not a list of buttons. It represents three stages
of real-world observing:

- **Naked Eye:** a wide field for learning the general direction and recognizing
  bright or large targets. Faint objects may be only tiny points or nearly
  invisible.
- **Finder Scope:** a narrower field for refining the target position. The player
  learns why a finder scope is useful before being asked to calibrate or use it.
- **Telescope:** a narrow field for centering the object precisely before entering
  the detailed Telescope View.

The interface presents azimuth and altitude scales, degree-minute-second
values, signed offsets, direction guidance, field of view, target visibility and
the current observing mode. The target marker, lock radius, click region and
actual completion check are intended to use the same coordinate system.

### Telescope View and Optical Feedback

The Telescope View separates two questions that are often confused:

1. **Is the focus correct?** The focal plane must be aligned with the eyepiece.
2. **Is the observation quality sufficient?** Aperture, stability, seeing,
   clouds, brightness, magnification, tracking and target type influence this.

The player can adjust focus with a slider or keyboard controls. A correct focus
should produce a sharp image even when the overall quality is limited by poor
conditions. A poor-quality image should not incorrectly claim that focus failed.
The visual states are intended to communicate the cause: blur and double image
for focus error, soft motion for seeing, dimming for low light or clouds, color
separation for refractor chromatic aberration, and drift for an untracked target.

### Mission and Free Observation

Mission targets use the gold mission flow and can advance the campaign after the
player completes the required observation and identification. Other visible
objects can be selected for **Free Observation** without accidentally completing
or changing the current mission. Free observations use a separate cyan detail
panel, show astronomy information and observing advice, and can be recorded in
the Club Logbook as independent practice.

### Learning Cards and Club Logbook

Concept Briefs are visual lessons shown before a new operation. Mission Complete
cards summarize the result, reward and concept learned. The Club Logbook stores
completed missions, concept cards, observation quality and process details such
as focus, tracking and collimation results.

The current teaching image pipeline uses large pixel diagrams rather than tiny
thumbnail illustrations. Images keep their aspect ratio with nearest-neighbour
rendering so optical paths, focal planes and light-gathering comparisons remain
readable.

### Sky Coordinates and Observing Locations

The sky-position layer can use live service data when configured and local
astronomical calculations when it is not. Fixed objects use RA/Dec data, while
solar-system bodies can use date-dependent calculations. The observing UI
reports the source as online, local calculation or offline fallback so the
player is not misled about precision.

When a target is below the horizon, the intended flow is not a dead end. The
game can explain the horizon problem, open a location-selection/world-map
transition, recommend a site where the target is above the horizon, and then
return the player to the observation flow. The location transition and layered
horizon scenery are active development areas and are being audited for visual
quality and continuity.

## Educational Progression

The progression is data-driven and follows a gradual increase in responsibility.
The exact playable order comes from `data/campaign_order.json`; numeric level
IDs alone should not be used to infer the order.

### Early Learning Arc

- **L1-L2: Naked Eye Foundations.** How the eye forms an image, why the Moon
  and bright stars are visible, and why faint deep-sky objects are difficult.
- **L3-L6: First Refractor.** Assemble a basic refractor, learn focal planes,
  choose magnification, and use the finder scope.
- **L7-L9: Light Gathering and Deep Sky.** Compare aperture, field of view,
  faint targets and the limits of beginner equipment.
- **L10-L21: Repeated Skill Practice.** Revisit focus, magnification, finder
  navigation, light pollution, seeing and target selection with changed
  conditions rather than one isolated fact per mission.
- **L22-L25: Tracking and Chromatic Aberration.** Observe drift and tracking,
  then use refractor observations to discover red/blue color fringing and the
  limitations of lenses.

### Reflector and Advanced Instrument Direction

The reflector transition should be motivated by the refractor experience: the
player first sees color separation even when aiming and focusing are correct,
then learns that a mirror-based optical path avoids lens chromatic aberration.
The Newtonian family introduces a primary mirror, secondary mirror, spider,
focuser and collimation. A Dobsonian mount can then be introduced as a simpler,
stable reflector platform with a shorter focused lesson block rather than a
second copy of the entire Newtonian course.

The longer-term instrument direction includes Cassegrain-style systems, a
segmented infrared space telescope and FAST radio astronomy. These families
must be differentiated by optical or signal principles, assembly structure,
visual result and player operation. They should not become repeated versions of
the same focus-and-identify mission.

## Telescope Families

| Family | Core idea | Distinct player activity | Status |
| --- | --- | --- | --- |
| Refractor | Lens-based optical path | Focus, magnification and chromatic aberration | Core teaching path |
| Newtonian reflector | Primary/secondary mirrors | Nested tube assembly and collimation | Implemented and under polish |
| Dobsonian reflector | Newtonian optics with rocker mount | Short reflector practice and manual stability | Implemented in the advanced framework |
| Cassegrain | Folded optical path with central obstruction | Distinct mirror placement and rear focus | Artwork/data integration in progress |
| Infrared space telescope | Segmented mirror and infrared instruments | Deployment and wavelength interpretation | Framework/scaffold in progress |
| FAST radio telescope | Radio dish, suspended feed cabin and signal processing | Alignment, spectrum and pulse recording | Framework/scaffold in progress |

Gregorian content was identified as too close to the other folded-mirror
families for the current teaching plan and is being removed or kept out of the
active campaign rather than used as a redundant chapter.

## Technical Architecture

The project is data-driven so new targets, concepts and equipment can be tested
without scattering level-specific rules through the UI:

- `GameManager`: progress, localization, scene routing, observation context
  and save-compatible game state.
- `SaveManager`: local JSON save and migration support.
- `MissionManager`: level loading and campaign-order validation.
- `StoryManager`: Maya dialogue, first-use story events and recaps.
- `TeachingFlowManager`: Concept Brief state machine and one-time teaching
  triggers.
- `SkyPositionService`: coordinate calculations, online data and fallback
  status.
- `ObservationSystem`: optical statistics, environmental modifiers and quality
  evaluation.
- `AssemblyManager`: compatible parts, installation state and assembly gates.
- `TouchInput` and `MobileControls`: shared mobile input abstraction without
  changing the desktop keyboard path.

Important data is stored in JSON files for levels, campaign order, telescope
parts, celestial objects, dialogue, localization and learning cards. UI scenes
are mostly lightweight Godot scenes whose scripts construct the interface and
connect the data-driven systems.

## Repository Guide

| Path | Purpose |
| --- | --- |
| `scenes/` | Main menu, observatory, assembly, teaching, sky and telescope scenes |
| `scripts/ui/` | Screen construction, interaction and presentation logic |
| `scripts/systems/` | Save, mission, story, teaching, astronomy and observation systems |
| `data/` | Levels, campaign order, parts, celestial objects, dialogue and cards |
| `assets/` | Backgrounds, UI frames, telescope parts, celestial images and diagrams |
| `tools/` | Headless tests, screenshot capture and acceptance checks |
| `docs/` | Project status, handoff notes, progression design and release history |
| `.github/workflows/` | Automated Godot Web export and GitHub Pages deployment |

The most useful documentation files are:

- [`docs/VERSION_HISTORY.md`](docs/VERSION_HISTORY.md): detailed historical
  archive from the first prototype onward.
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md): English-first release log with
  dates and concrete changes.
- [`docs/PROJECT_STATUS.md`](docs/PROJECT_STATUS.md): current implementation,
  limitations and next priorities.
- [`docs/level_progression_directory.md`](docs/level_progression_directory.md):
  detailed level and teaching directory.
- [`docs/OBSERVATION_EXPANSION.md`](docs/OBSERVATION_EXPANSION.md): expansion
  targets, mechanisms and content notes.
- [`docs/mobile_controller_mode.md`](docs/mobile_controller_mode.md): touch
  input and mobile-control design.
- [`docs/WEBSITE.md`](docs/WEBSITE.md): web build and deployment notes.

## Current Status: 2026-07-22

### Verified and usable

- Complete early teaching loop from New Game to mission result and logbook.
- Maya story and first-use Concept Brief flow.
- Observatory base and proximity-based interaction.
- Refractor assembly and nested Newtonian/Dobsonian tube assembly framework.
- Naked-eye, finder-scope and telescope observation modes.
- Focus, magnification, aperture, stability, seeing, clouds, drift, tracking,
  dark adaptation and light-pollution feedback paths.
- Mission observations separated from free observations.
- Dynamic coordinates, DMS guidance and horizon visibility data paths.
- Learning cards with large diagrams and Club Logbook records.
- Mobile virtual controls and touch scrolling for the parts cabinet.
- Godot Web export workflow and public custom-domain delivery.

### Still in active development

- Final artwork and blueprint alignment for advanced telescope families.
- More distinctive missions and targets after the first reflector transition.
- World-map and below-horizon transitions with stronger cinematic presentation.
- Complete atmosphere, cloud, horizon and parallax visual polish.
- Better first-use guidance in every expanded observation and assembly screen.
- Real-device Android layout and touch testing across aspect ratios.
- Final balance pass so advanced families do not repeat the same target,
  concept card or interaction too many times.

### Known limitations

- Some advanced families still use scaffold data or temporary artwork and are
  not yet a finished 1.0 content experience.
- Live sky data depends on external service availability and configured local
  credentials; offline/local calculation status is shown when live data is not
  available.
- Web play is available, but Android release still requires a Godot APK export
  and real-device testing.
- The project contains historical prototype/plugin artifacts that are not part
  of the player-facing game.

## Latest Verified Update

The latest focused update did two things:

1. Replaced the `naked_eye_limits` Concept Brief thumbnail with a larger
   light-gathering diagram showing the relationship between the eye pupil,
   telescope aperture and faint objects.
2. Added mobile swipe scrolling to the Parts Cabinet. A short tap selects a
   card; a vertical drag scrolls the list without accidentally equipping a
   part. Desktop mouse-wheel behavior remains available.

Relevant files include:

- `data/learning_cards.json`
- `assets/learning_diagrams/naked_eye_limits_light_gathering.png`
- `scripts/ui/learning_card.gd`
- `scripts/ui/parts_cabinet.gd`
- `tools/learning_card_diagram_test.gd`
- `tools/parts_cabinet_touch_test.gd`

## Historical Release Summary

The detailed records are preserved in `docs/VERSION_HISTORY.md` and expanded
in `docs/CHANGELOG.md`. The major milestones are:

| Version | Theme |
| --- | --- |
| v0.1 | Project replacement, MVP scenes, managers and JSON data |
| v0.2 | Movable Observatory Room and interactive base objects |
| v0.3 | Observatory interior redesign and clearer room routing |
| v0.4 | Playable Parts Tray, Blueprint and Inspector assembly loop |
| v0.5 | First complete Moon mission, identification and logbook flow |
| v0.6 | Distinct pixel-art sky targets and mission selection UI |
| v0.7 | Telescope View, quality states and separated identification |
| v0.8 | Parts Cabinet and Assembly Table information-architecture split |
| v0.9 | Full observatory background and transparent interaction layer |
| v1.0 | Four-direction player sprites, animation frames and foot anchors |
| v1.1 | Coordinate-aware sky positions and online/offline fallback paths |
| v1.2 | Pre-operation teaching and Concept Brief state management |
| v1.3 | Focus Knob as a real part and DMS coordinate feedback |
| v1.4 | Large readable Learning Card diagrams |
| v1.5 | Orion Nebula focus/quality pass and clearer failure reasons |
| v1.6 | Starlight Observatory main menu and web-facing visual identity |
| v1.7 | Unified Eye/Finder/Scope mode buttons |
| v1.8 | Jupiter clear/blurry/dim visual observation states |
| v1.9 | Advanced telescope framework, assembly feedback and observation HUD |
| v2.0 | Web delivery, mobile controller mode and touch interactions |
| 2026-07-22 | Learning diagram replacement and Parts Cabinet touch scrolling |

## Web Version

Play the current public build:

<https://pixelobservatorygame.com/>

Source repository:

<https://github.com/tntsg1/Pixel-Observatory>

The web build is exported by GitHub Actions and deployed through GitHub Pages.
The custom domain is fronted by Cloudflare. Source changes do not change the
live site until the web export workflow succeeds and the deployment finishes.

## Future Direction: Version 1.0

The project's 1.0 goal is not simply “more levels.” It is a coherent complete
learning game in which every new instrument has a reason to exist and every
mechanic is visible in play. The remaining high-value work is:

1. Finish the refractor-to-reflector story and explain the color-aberration
   motivation before the first Newtonian assembly.
2. Make Newtonian and Dobsonian assembly, collimation and observation feel
   complete without repeating the entire refractor course.
3. Finish Cassegrain, infrared and FAST artwork and give each family a unique
   principle and interaction.
4. Replace repeated target/card content with varied targets, conditions and
   scientific decisions.
5. Make below-horizon travel, world-map site selection and horizon scenery a
   clear, attractive part of the observing journey.
6. Complete first-use guidance, animation feedback, UI layering and mobile
   touch behavior across the whole campaign.
7. Run a final playthrough from a clean save, verify the public Web build, and
   document limitations and asset provenance for release.

## Development and Validation

Godot 4.7 is the target runtime. The project uses GDScript, JSON data,
nearest-neighbour pixel rendering and automated acceptance scripts in `tools/`.
The latest Agent report states that the focused learning-card and mobile-cabinet
tests passed together with the broader regression suites. A local Godot CLI is
not assumed to be available in every shell, so a fresh runtime check should be
made in Godot or confirmed by CI before release.

When changing a level or telescope family, update the data, story, teaching
card, equipment gate, artwork, route guidance and regression coverage together.
A feature is not complete merely because it compiles: a first-time player must
be able to understand what to do, see the result, and know why the result
changed.

## Language, Credits and License

English is the primary project and documentation language. The game also
supports Chinese through its language setting. Player-facing strings should use
the shared localization helpers and should not mix languages accidentally.

This is an active educational game project and portfolio/research prototype.
Asset provenance, historical decisions and release notes are documented in
`docs/`.
