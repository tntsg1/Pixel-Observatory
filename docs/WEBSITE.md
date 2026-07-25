# Website and Web Release

## Public Website

- URL: <https://pixelobservatorygame.com/>
- Repository: <https://github.com/tntsg1/Pixel-Observatory>
- Game title: Pixel Observatory
- Delivery format: Godot Web export

The public URL returned HTTP 200 and the Godot Web entry page was reachable in
the latest check. The live page is a built artifact, not a direct view of the
working tree.

## Deployment Path

The checked-in workflow is `.github/workflows/deploy-web.yml`. It runs on
pushes to `main` and `agent/current-version-2026-07-18`, or by manual dispatch.
It performs the following steps:

1. Installs Godot 4.7 and the matching Web export templates.
2. Exports the project to `build/web/index.html`.
3. Adds the Pixel Observatory web shell: a branded loading/start layer, a
   responsive game frame and a visitor-count client.
4. Uploads `build/web` as a GitHub Pages artifact.
5. Deploys the artifact through the GitHub Pages environment.

The repository also contains `wrangler.jsonc`, `cloudflare/worker.mjs`, and
`build/cloudflare-public/`. These files describe the Cloudflare delivery layer
and custom-domain configuration. Do not change the production path to a
direct Wrangler deployment unless the GitHub Pages and Cloudflare routing
decision has been made deliberately.

The Cloudflare Worker also owns the `/api/visits` endpoint. It uses a Durable
Object to store an anonymous browser identifier and a total. A browser is
counted once, so normal refreshes do not inflate the public number. It is a
privacy-preserving visitor estimate, not a claim of exact human identity.

## Publishing a New Version

1. Confirm that the Godot project opens without script errors.
2. Run the focused tests relevant to the change.
3. Export and test the Web build, including a hard refresh in a browser.
4. Commit only the intended source, data, asset, and documentation files.
5. Push the release branch or merge to `main`.
6. Open the GitHub Actions run and wait for both `build` and `deploy` jobs.
7. Open `https://pixelobservatorygame.com/` in a private window and verify the
   game title, loading screen, input, and the changed feature.
8. Record the date, commit, and user-visible changes in `docs/CHANGELOG.md`.

## Current Release Note

The next Web export includes the advanced-observatory interaction pass and a
branded browser shell. The shell is generated after each Godot export, so it
always wraps the current game build instead of becoming a separate stale site.

## Important Distinction

Pushing source code to GitHub does not automatically update the live game
unless the deployment workflow succeeds. Local Godot scenes, generated caches,
temporary saves, and screenshots are not a substitute for a completed Web
export.
