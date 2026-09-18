# Bikr

[![CI](https://github.com/mchamow/bikr/actions/workflows/ci.yml/badge.svg)](https://github.com/mchamow/bikr/actions/workflows/ci.yml)

A super simple bike ride recorder and track follower for iPhone (iOS 26+).

- **Record rides**: start, pause, resume, finish. Keeps recording with the screen locked.
- **Live stats**: time, distance, current and average speed.
- **Ride history**: distance, moving and total time, average and max speed, climb, and a map of each ride.
- **GPX**: share any track as a `.gpx` file. Import GPX files from the Tracks tab, or open them in Bikr from Files, Mail or Safari.
- **Works with no signal**: recording, stats, following a track and its warnings never touch the network. Without a connection Bikr draws your track, position, heading, a north arrow and a scale bar itself. Apple's map is the extra on top when you're online, and the map button turns it off any time.
- **Rides survive a crash**: the ride is written to disk as you go, so if iOS shuts Bikr down mid-ride, the next launch offers the ride back.
- **Follow a track**: pick a recorded ride or an imported GPX file. Bikr shows it on the map with distance done and to go. When you stray more than 40 m it warns you with a haptic and a notification, and a dashed line leads back to the track.

## Layout

```
Bikr.xcodeproj           Xcode project (folders are synced, so new files under Bikr/ are picked up)
Config/Info.plist        Location + background mode, GPX file type
Bikr/
  App/                   App entry point and AppModel (app-wide state)
  Riding/                GPS feed, ride recorder, track guide, alerts
  Views/                 Ride screen, Tracks list, track detail, offline drawing
  Support/               Formatting, GPX sharing, CoreLocation bridges
BikrUITests/             UI smoke test of the record → save → follow flow
scripts/                 Test runners, and make-app-icon.swift which draws the icon
Samples/                 A sample GPX route to import
Packages/BikrCore/       Platform-independent logic, unit-tested
  Track, TrackStats      Model and ride statistics
  GPX                    GPX read/write
  TrackStore             Tracks saved as JSON files in Application Support
  RideDraft              The ride in progress, appended to disk point by point
  TrackFollower          Matches GPS positions to a track (progress, off-track)
  LocationFilter         Drops noisy GPS fixes
```

## Running

1. Open `Bikr.xcodeproj` in Xcode.
2. Under **Bikr target → Signing & Capabilities**, pick your team. Change the bundle identifier if `com.michalchamow.bikr` is taken.
3. Run on an iPhone for real rides. In the Simulator, use **Features → Location → City Bicycle Ride** to fake a ride.

To try the sample track in the Simulator, "open" it the way Files or Safari would:

```sh
xcrun simctl openurl booted "file://$PWD/Samples/vistula-loop.gpx"
```

## Tests

`⌘U` in Xcode runs both the unit tests and the UI test. From the terminal:

```sh
./scripts/test-core.sh   # BikrCore unit tests (fast, no simulator)
./scripts/ui-test.sh     # UI smoke test: records a ride on a simulated route,
                         # saves it, then follows it
```

`scripts/ui-test.sh` makes the simulator ride a route through Kraków while the test runs,
so the recorded ride has real distance in it. Without a device name it picks the newest
iPhone simulator it can find.

Both run on every push and pull request via GitHub Actions (`.github/workflows/ci.yml`),
on a `macos-26` runner — free for public repositories.
