# KEXP Menu Bar

A tiny macOS menu bar player for [KEXP 90.3 FM](https://www.kexp.org), Seattle's listener-powered radio station.

- Play / stop the live stream from the menu bar
- See what's on: song, artist, album art, and the current show and host
- Like songs. They're saved locally so you can look them up later.
- Media keys and Control Center's Now Playing work
- The menu bar bars bounce while it plays (can be turned off)

Requires macOS 14 or later. Runs on Apple Silicon and Intel.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask gosborn/tap/kexp
```

Or download `KEXP.zip` from the [latest release](https://github.com/gosborn/kexp-menu-bar/releases/latest), unzip it, and drag `KEXP.app` to Applications. Releases are signed and notarized by Apple.

## Liked songs

Likes are stored as JSON in `~/Library/Application Support/KEXP Menu Bar/likes.json`. "Show likes file in Finder" in the dropdown opens it.

## Building

```sh
./build.sh            # build/KEXP.app for this Mac
./build.sh --install  # same, copied to /Applications
./build.sh --release  # universal, Developer ID signed + notarized -> build/KEXP.zip
```

`--release` needs a Developer ID Application certificate and a `kexp-notary` notarytool profile; see the comments at the top of `build.sh`. You can also open `Package.swift` in Xcode.

## Not affiliated with KEXP

This is an unofficial fan project. KEXP's name and logo belong to KEXP. Audio and playlist data come from KEXP's public stream and API. If you enjoy the station, [support KEXP](https://www.kexp.org/donate/).
