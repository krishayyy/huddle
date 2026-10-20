# Huddle

Teens put their phones down together and play conversation games in real time.

1. **Lock together** – one person starts a huddle, friends join nearby (no internet needed,
   uses MultipeerConnectivity). The host picks a time; every phone shows a shared countdown.
   With **Lock all my other apps** on, Apple's Screen Time API blocks every other app and website
   on that phone until the timer ends (calls and emergency stay available), while Huddle stays open
   for the games. Leaving Huddle still counts as a "peek" and everyone sees it.
2. **Games** (all synced live, designed so people look up and talk, not at the screen):
   Imposter, Most Likely To, Never Have I Ever, Would You Rather, Act It Out, Two Truths & a Lie,
   Hot Seat. Points and a leaderboard for Imposter and Two Truths.

## Fresh every day
The host's phone fetches `content/daily.json` once a day (data only, filtered for length and
unsafe words). It sets a theme, pins a featured game with a TODAY badge, and mixes new prompts in
ahead of the built-in ones. If the file isn't dated today or the phone is offline, a built-in
weekday rotation takes over, so stale "trends" never show as today's. Update the file daily (or on a
schedule) with prompts a person has approved.

## Build
Requires a Mac with Xcode 15+ and two or more real iPhones (Multipeer doesn't work well in the simulator).

```bash
brew install xcodegen
cd Huddle && xcodegen && open Huddle.xcodeproj
```
Set your team in `project.yml` first. No XcodeGen? Make a new iOS App project (SwiftUI, iOS 17),
drag in `Sources/`, and copy the Info.plist keys from `project.yml`.

## Honest limits
- The full lock uses Apple's Screen Time API (FamilyControls). It only runs on real devices and needs
  the Family Controls entitlement: development builds work with your own team, but App Store release
  needs Apple's approval. The lock is lifted by a background extension (HuddleMonitor) at the end time
  even if Huddle was closed, and also blocks deleting apps and changing the clock while locked.
  Phone calls and emergency features can never be blocked by iOS.
- Without the entitlement, delete it from `project.yml` and Huddle falls back to a social-pressure lock.
- Two Truths' answer is in the synced state, so a determined hacker could peek. Fine for friends.
- Untested: written without access to Xcode, so expect a few small compile fixes. Work through [TESTING.md](TESTING.md) on real phones.
- App Store: this is a kids' app, so plan for the Kids/Family guidelines and COPPA. Huddle collects
  no accounts or data and only talks device-to-device, which helps.

## Ideas next
Streaks and weekly leaderboards, more games (Charades prompts, Story Chain), parent dashboard, widgets.
