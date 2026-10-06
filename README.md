# Amend

A lightweight macOS app for proofreading with AI: paste your original and the revised text, see what changed, and **accept or reject** each change.

- Live diff as you type (deletions in red, insertions in green)
- Click a change in the comparison pane to accept or reject it
- Both panes are editable; full undo/redo
- Scrolling stays in sync between the two panes
- Once every change is resolved, the **Revised** pane holds the final text — hit `Copy Result`
- No dependencies, under 1 MB

## Shortcuts

| Action | Key |
|---|---|
| Accept / Reject | ⌘↩ / ⇧⌘↩ |
| Next / Previous change | ⌘] / ⌘[ |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Copy result | ⇧⌘C |
| Show/hide comparison | ⌥⌘I |
| Font size | ⌘+ / ⌘- / ⌘0 |

## Install

Download `Amend-x.y.z.zip` from [Releases](../../releases), unzip, and move `Amend.app` to Applications.

The app is not notarized, so macOS may block the first launch. Right-click the app → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Amend.app
```

Requires macOS 13 or later (Apple Silicon and Intel).

## Build

```sh
swift test                  # diff engine tests
swift run                   # run in development
scripts/build-app.sh 0.1.0  # build/Amend.app + zip
```

Pushing a `v*` tag builds a GitHub release.

## How it works

Text is split into words, whitespace and punctuation, then compared with a Myers diff (Swift's `CollectionDifference`). As in diff-match-patch's semantic cleanup, edits separated by a short unchanged span are merged into one change. Within a word, a shared prefix/suffix of two or more characters is left unhighlighted, so only the characters that changed stand out.

Inspired by [compareDoc](https://wepplication.github.io/tools/compareDoc/), [jQuery.PrettyTextDiff](https://github.com/arnab/jQuery.PrettyTextDiff) and [jQuery.picadiff](https://github.com/picapica-org/jQuery.picadiff).

## License

MIT
