# Pixel Observatory study flow

The study endpoint is packaged at `https://pixelobservatorygame.com/study`.
The Worker rewrites both `/study` and `/study/` to a non-directory static
entry page so the published link has one stable, easy-to-share address.

## Participant flow

1. Read consent and receive an anonymous study id.
2. Complete a short baseline knowledge check.
3. Read the four concept notes and complete the reading check.
4. Launch the game with a one-time anonymous study token. The game records only
   active seconds for that study token, not a game account name.
5. Return after at least five active minutes for the post-game check and a short
   experience survey.

The three knowledge scores allow the analysis to separate the change after
reading (`reading_post - pre`) from the change after playing (`post - reading_post`).
The server calculates scores; it never trusts a browser-provided score.

## Data handling

`study_participants` and related response/event tables do not contain an account
user id, username, email, or IP address. The export endpoint is restricted to
an administrator session:

`GET /api/admin/study/export`

Before formal recruitment, replace the provisional consent wording with the
version approved by the course instructor or ethics process, and set the study
dates, inclusion criteria, and retention period.
