# Harmonia

**Harmonia** is a native iOS music player built with **SwiftUI**,
**AVFoundation**, and **AVAudioEngine**.

The project focuses on local music playback, a modern artwork-first
interface, advanced audio controls, background playback, and a playback
architecture capable of gapless transitions and real dual-node
crossfade.

> Harmonia is currently a learning and portfolio project under active
> development.

## Highlights

-   Native SwiftUI interface with an immersive, artwork-focused design
-   Local audio file and folder import
-   Recursive folder scanning for supported audio files
-   Metadata and embedded artwork extraction
-   SHA-256 content fingerprinting for duplicate detection
-   Library browsing by songs, albums, artists, and playlists
-   Search, favorites, recently added, and playback history
-   Mini Player and full Now Playing experience
-   Editable Up Next queue
-   Shuffle and Repeat Off / All / One
-   Background audio playback
-   Lock Screen and Control Center integration
-   Gapless playback
-   Configurable **2 / 4 / 6 / 8 / 10 second crossfade**
-   Dual `AVAudioPlayerNode` playback architecture
-   Equalizer presets
-   Playback speed control
-   Volume control
-   Real audio-level visualization using an `AVAudioEngine` tap
-   Sleep timer
-   Audio interruption and route-change handling
-   Persistent playback preferences
-   Restoration of the last song, playback position, queue, shuffle, and
    repeat state
-   Centralized Settings screen
-   Haptic and accessibility-oriented UI behavior

## Screenshots

Screenshots will be added as the Harmonia 1.0 interface is finalized.

  Library         Now Playing     Settings
  --------------- --------------- ---------------
  *Coming soon*   *Coming soon*   *Coming soon*

## Audio Architecture

Harmonia originally used `AVAudioPlayer`, but the playback layer evolved
to `AVAudioEngine` to provide greater control over scheduling, effects,
visualization, and transitions.

The current signal path is conceptually:

``` text
Player Node A ─┐
               ├── Crossfade Mixer
Player Node B ─┘
                       │
                       ▼
                AVAudioUnitTimePitch
                       │
                       ▼
                  AVAudioUnitEQ
                       │
                       ▼
                  Main Mixer
                  │         │
                  │         └── PCM Tap → Audio Level Visualizer
                  ▼
                 Output
```

When crossfade is disabled, Harmonia schedules the successor on the
active player node for gapless playback. When crossfade is enabled, the
next track is scheduled on the standby node and both nodes overlap
through the shared mixer.

`AVAudioSession` uses the `.playback` category and is activated away
from the main thread. The target declares the `audio` background mode,
allowing playback to continue while Harmonia is in the background or the
device is locked.

## Architecture

Harmonia separates UI state, playback, library management, importing,
and persistence instead of putting those responsibilities directly in
SwiftUI views.

``` text
SwiftUI Views
     │
     ├── PlayerViewModel
     │      ├── playback state
     │      ├── queue / shuffle / repeat
     │      ├── sleep timer
     │      └── Now Playing / remote commands
     │
     ├── MusicLibraryStore
     │      ├── songs
     │      ├── playlists
     │      ├── favorites
     │      └── import state
     │
     └── Services
            ├── AudioPlayerService
            ├── AudioSessionService
            ├── MusicImportService
            ├── LibraryPersistenceService
            ├── PlaybackPreferencesService
            ├── PlaybackSessionPersistenceService
            └── HapticService
```

`PlayerViewModel` remains the observable source of truth for
playback-facing SwiftUI state, while low-level audio work is delegated
to the audio services.

## Music Import

Harmonia can import individual audio files or recursively scan a
selected folder.

Imported audio is copied into Harmonia's private music directory so
playback does not depend on temporary document-picker URLs.

During import, Harmonia:

1.  Obtains security-scoped access when required.
2.  Discovers supported audio files.
3.  Calculates a SHA-256 fingerprint incrementally.
4.  Skips content that already exists in the library.
5.  Copies accepted files into the app's private music directory.
6.  Reads metadata such as title, artist, album, duration, and artwork.
7.  Reports import progress, duplicates, and failures.

Duplicate detection is based on **file content**, not the filename.
Renaming an identical file therefore does not create a second library
entry.

## Playback Features

### Gapless Playback

With Crossfade set to **Off**, the next audio file is scheduled ahead of
time on the active player node. This avoids relying on UI polling to
start the successor after the previous track has already finished.

### Crossfade

Harmonia uses two `AVAudioPlayerNode` instances for real overlapping
playback.

Available settings:

-   Off
-   2 seconds
-   4 seconds
-   6 seconds
-   8 seconds
-   10 seconds

Both nodes share the same effects/output pipeline.

### Equalizer

Current presets include:

-   Flat
-   Bass Boost
-   Treble Boost
-   Vocal
-   Rock
-   Electronic

The equalizer is implemented with `AVAudioUnitEQ`.

### Playback Speed

Playback rate is applied through `AVAudioUnitTimePitch`.

### Audio Visualization

Harmonia installs a PCM tap on the audio engine's main mixer and derives
a live audio level from the actual signal. The visualizer is therefore
driven by playback audio rather than by a decorative random animation.

### Sleep Timer

The player supports:

-   15 minutes
-   30 minutes
-   45 minutes
-   1 hour
-   End of Song

The active timer can also be cancelled from the player settings.

## Playback Restoration

Harmonia persists the active playback session independently from
long-lived playback preferences.

The saved session includes the current song, playback position, queue,
shuffle state, and repeat mode.

When Harmonia launches again, it restores the previous song and position
in a **paused** state. It intentionally does not autoplay after launch.

## Background Playback & System Media Controls

Harmonia supports background playback using the iOS audio background
mode and an `AVAudioSession` configured for `.playback`.

`MPRemoteCommandCenter` and `MPNowPlayingInfoCenter` provide integration
with:

-   Lock Screen
-   Control Center
-   Bluetooth controls
-   Headphones / AirPods media controls

The playback layer also handles audio interruptions and route changes
such as output-device disconnection.

## Settings

The Settings experience centralizes the application's playback and audio
configuration.

Current settings include:

-   Crossfade duration
-   Gapless playback status
-   Playback speed
-   Sleep timer
-   Equalizer preset
-   Volume
-   File and folder import
-   Library song count
-   Duplicate-detection status
-   Dynamic artwork colors
-   Player visualizer
-   Haptic feedback
-   App/version information

Playback preferences are persisted between launches.

## Project Structure

``` text
Harmonia/
├── Components/
│   ├── ArtworkView.swift
│   ├── AudioLevelView.swift
│   └── SongRow.swift
├── DesignSystem/
│   └── HarmoniaTheme.swift
├── Features/
│   ├── Albums/
│   ├── Artists/
│   ├── Library/
│   ├── Player/
│   ├── Playlists/
│   ├── Search/
│   └── Settings/
├── Models/
│   ├── LibrarySnapshot.swift
│   ├── PlaybackSession.swift
│   ├── PlaybackSettings.swift
│   ├── RepeatMode.swift
│   └── Song.swift
├── Services/
│   ├── AudioPlayerService.swift
│   ├── AudioSessionService.swift
│   ├── HapticService.swift
│   ├── LibraryPersistenceService.swift
│   ├── MusicImportService.swift
│   ├── PlaybackPreferencesService.swift
│   └── PlaybackSessionPersistenceService.swift
├── Assets.xcassets/
├── ContentView.swift
├── HarmoniaApp.swift
└── Info.plist
```

## Persistence

Harmonia currently uses dedicated encoded local persistence services for
library data, playback preferences, and playback-session restoration.

The project **does not currently use SwiftData**.

This separation keeps persistence responsibilities explicit while the
data model continues to evolve.

## Requirements

The current Xcode project is configured with:

-   iOS deployment target: **26.0**
-   Swift
-   SwiftUI
-   AVFoundation / AVFAudio
-   MediaPlayer
-   CryptoKit
-   Xcode capable of building the configured iOS SDK

A physical iPhone is recommended when testing background audio, Lock
Screen controls, audio routes, and interruption behavior.

## Running the Project

1.  Clone or download the repository.
2.  Open `Harmonia.xcodeproj` in Xcode.
3.  Select the **Harmonia** target.
4.  Choose a compatible iPhone or simulator.
5.  Verify signing for your development team if required.
6.  Build and run with **⌘R**.
7.  Import audio using **Import Files** or **Import Folder**.

For background playback testing, use a physical device and verify that
the Harmonia target has **Background Modes → Audio, AirPlay, and Picture
in Picture** enabled.

## Testing

The repository contains both unit-test and UI-test targets:

``` text
HarmoniaTests/
HarmoniaUITests/
```

As Harmonia approaches its 1.0 release, the test suite is intended to
cover the playback state machine, queue behavior, shuffle/repeat
behavior, persistence, importing, duplicate detection, and critical UI
flows.

## Current Status

Harmonia is approaching its **1.0 stabilization stage**.

The primary feature set is in place. The next focus is QA and release
readiness, including regression testing of:

-   Background playback
-   Gapless playback
-   Crossfade
-   Pause / resume / seek
-   Shuffle and repeat
-   Queue editing
-   Lock Screen and Control Center commands
-   Sleep timer
-   EQ and playback speed
-   Audio interruptions and route changes
-   Playback-session restoration
-   Large-library performance

## Roadmap

### Harmonia 1.0

-   QA and regression testing
-   Performance and memory profiling
-   Accessibility review
-   Final visual polish
-   App icon and launch experience
-   Expanded automated tests
-   Release configuration and App Store preparation

### Future Ideas

Potential post-1.0 work includes:

-   SwiftData evaluation/migration
-   iCloud synchronization
-   Smart playlists
-   Listening statistics
-   Synchronized lyrics
-   Widgets
-   CarPlay
-   iPadOS and macOS experiences
-   Additional library-management tools

## Design Goals

Harmonia is built around a few principles:

-   **Native first** --- use Apple's frameworks rather than wrapping a
    web experience.
-   **Artwork first** --- music artwork should influence the visual
    experience.
-   **Real audio behavior** --- features such as visualization and
    crossfade should be backed by the audio engine, not simulated in the
    UI.
-   **Local ownership** --- imported music remains under the
    application's local library model.
-   **Clear separation of responsibilities** --- SwiftUI views should
    not own low-level playback, import, or persistence logic.
-   **Production-minded learning** --- the project is also used to
    explore modern Swift, SwiftUI, AVFoundation, concurrency, and iOS
    application architecture.

## License

No open-source license has been added yet. Until a license is explicitly
provided, the source code should be considered all rights reserved.

