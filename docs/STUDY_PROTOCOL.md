# Pixel Observatory study flow

The study endpoint is packaged at `https://pixelobservatorygame.com/study`.
The Worker rewrites both `/study` and `/study/` to a non-directory static
entry page so the published link has one stable, easy-to-share address.

## Participant flow

1. Read consent and receive an anonymous study id.
2. Complete a short baseline knowledge check.
3. Read the four concept notes and complete the reading check.
4. Complete the embedded study observatory: acquire M42 through naked-eye,
   finder, and main-telescope views; configure useful magnification, focus, and
   tracking; then produce infrared false-colour and radio-dispersion evidence.
   This mini-game has its own participant-scoped browser save and never reads or
   changes the main Pixel Observatory game save.
5. Return after at least five active minutes for the post-game check and a short
   experience survey.

The three knowledge scores allow the analysis to separate the change after
reading (`reading_post - pre`) from the change after playing (`post - reading_post`).
The server calculates scores; it never trusts a browser-provided score.

## Language and mini-game scope

The page defaults to English. It follows the main site's saved `so-lang`
preference when one exists, accepts `?lang=en` or `?lang=zh`, and provides an
English/Chinese switch in the top-right corner. Language changes preserve
in-progress questionnaire answers and the study mini-game state.

The mini-game intentionally covers only concepts measured by the questionnaire:
the naked-eye/finder/main-scope workflow, eyepiece magnification, focus,
atmospheric seeing, sidereal tracking, false-colour infrared mapping, and pulsar
dispersion correction. It does not open the main game or require a game account.
Only time while the study tab is visible and focused is submitted as active time.

## Data handling

`study_participants` and related response/event tables do not contain an account
user id, username, email, or IP address. The export endpoint is restricted to
an administrator session:

`GET /api/admin/study/export`

Before formal recruitment, replace the provisional consent wording with the
version approved by the course instructor or ethics process, and set the study
dates, inclusion criteria, and retention period.
