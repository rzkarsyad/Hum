# Hum — notes for agents

## Commits

Never add `Co-Authored-By:` trailers, "Generated with …" lines, or any other
tool attribution to commit messages or pull request descriptions. The
contributor list on this repository stays human.

## Layout

- `Hum/` — the macOS app. Swift and SwiftUI, target macOS 15.
- `HumTests/` — unit tests. `xcodebuild test` is a required status check on
  `main`, so keep it green.
- `site/` — the landing page. Next.js with a static export; Vercel builds it
  from this directory on every push to `main` and serves it at
  <https://hum.arsat.work>.
- `appcast.xml` — the Sparkle feed. Release DMGs are attached to GitHub
  releases and their download URLs are built from the tag and the file name,
  so published tags must not be renamed or deleted.

## History

The history was rewritten on 2026-09-12 to remove old attribution trailers, so
every commit hash changed. If a checkout has diverged, reset it to
`origin/main` instead of merging.
