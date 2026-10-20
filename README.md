# Huddle

Teens put their phones down together and play conversation games in real time.

1. **Lock together** – one person starts a huddle, friends join nearby (no internet needed,
   uses MultipeerConnectivity). The host picks a time; every phone shows a shared countdown.
   Leaving the app counts as a "peek" and everyone sees it. Optionally blocks the teen's chosen
   apps with Apple's Screen Time API.
2. **Games** – Would You Rather, Hot Seat, Two Truths & a Lie, synced live across phones.

## Build
Requires a Mac with Xcode 15+ and two or more real iPhones (Multipeer doesn't work well in the simulator).

```bash
brew install xcodegen
cd Huddle && xcodegen && open Huddle.xcodeproj
```
Set your team in `project.yml` first. No XcodeGen? Make a new iOS App project (SwiftUI, iOS 17),
drag in `Sources/`, and copy the Info.plist keys from `project.yml`.

## Honest limits
- iOS apps cannot truly lock the whole phone. The hard block uses FamilyControls, which needs
  Apple's approval of the Family Controls entitlement. Without it, delete the entitlement and
  Huddle works as a social-pressure lock.
- Two Truths' answer is in the synced state, so a determined hacker could peek. Fine for friends.
- Untested: written without access to Xcode, so expect a few small compile fixes.
- App Store: this is a kids' app, so plan for the Kids/Family guidelines and COPPA. Huddle collects
  no accounts or data and only talks device-to-device, which helps.

## Ideas next
Streaks and weekly leaderboards, more games (Charades prompts, Story Chain), parent dashboard, widgets.
