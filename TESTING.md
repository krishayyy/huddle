# Button-by-button test checklist

Needs 3 iPhones (2 for most things, 3 for Imposter). Tick each after you've tried it.
"A" = host phone, "B"/"C" = guests.

## Home
- [ ] Name empty → both buttons look dimmed and do nothing; hint text shows
- [ ] Type name, press Done on keyboard → keyboard closes; drag the list → keyboard closes
- [ ] **Start a huddle** → lobby opens as host
- [ ] **Join friends nearby** → list appears; A's huddle shows up
- [ ] Tap a huddle → spinner, then lobby. If the host is gone: after ~16s "Couldn't join" shows
- [ ] **Cancel** (while browsing) → back to the two buttons

## Lobby
- [ ] Member chips update live as B and C join/leave
- [ ] Minutes picker (host only) changes the label on **Lock in**
- [ ] **Lock in** disabled with 1 person; enabled with 2+; all phones jump to the lock screen
- [ ] **Lock all my other apps** toggle → Screen Time permission appears; toggle stays on only if you allow it
- [ ] **Leave huddle** → asks first; **Stay** keeps you, **Leave/End huddle** exits (host leaving drops guests to Home)

## Lock screen
- [ ] Timer and ring count down identically on all phones
- [ ] **Play a game** → sheet; **Done** closes it
- [ ] **I need my phone** → asks first; **Keep going** does nothing; confirm → others see "peeked" and feel a buzz
- [ ] Switch to another app on B → A and C see B's peek count go up (once, not twice)
- [ ] Return B to the app → still on lock screen, bail count kept (banner "Reconnecting…" may flash)
- [ ] **End for everyone** (host only) → asks first; everyone returns to lobby
- [ ] Let the timer hit 0 → everyone returns to lobby, confetti if you never peeked; Home stats go up

## Full lock (real devices, entitlement required)
- [ ] With the toggle on, start a lock → lock screen says "Everything else on your phone is locked"
- [ ] Press Home → tapping any other app shows the "Locked with friends" screen
- [ ] Phone calls still work; Huddle still opens and games still sync
- [ ] Try deleting an app and changing the date/time → both blocked
- [ ] Force-quit Huddle mid-lock → apps stay locked, then unlock by themselves at the end time
- [ ] **I need my phone** and **End for everyone** both unlock immediately
- [ ] Toggle off (or deny the permission) → lock screen warns other apps aren't blocked

## New: coaster, Live Activity, stats
- [ ] **Huddle stays usable during a full lock** (most important: if Huddle itself gets the "Locked with friends" screen, tell the team right away)
- [ ] Host taps **End for everyone** with full lock on → guests' other apps unlock immediately too
- [ ] **Tap a Huddle coaster** on a blank sticker → "New Huddle coaster ready", phone starts a huddle
- [ ] Second phone taps the same coaster → joins that huddle automatically (no list)
- [ ] During a lock, lock the phone → countdown shows on the lock screen and in the Dynamic Island
- [ ] Someone peeks → "X of Y still locked in" updates on the lock screen
- [ ] Lock ends or is ended → the Live Activity disappears
- [ ] Finish a lock without peeking → Home "phone-free with friends" goes up by minutes × friends
- [ ] Settings → Accessibility → Larger Text at max: Home and lobby still readable, nothing cut off
- [ ] VoiceOver on Home: stats read as one item each, the hug emoji is skipped

## Games (try each on 2+ phones; Imposter on 3+)
- [ ] Each tile starts its game on every phone; Imposter tile dimmed with "Needs 3+ people" with 2 people
- [ ] **Next round** → new prompt, no repeats until the list runs out; **End game** → back to picker
- [ ] Would You Rather: tap to vote, tap other side to change; reveals when all voted or **Reveal now**
- [ ] Most Likely To: tap a friend to vote; crown on top vote; **Reveal now**
- [ ] Never Have I Ever: **I have / Never**; answers hidden until reveal
- [ ] Hot Seat: **Different question** only on the hot-seat phone; seat rotates on **Next round**
- [ ] Two Truths: **truth/lie** toggle, **Lock it in** disabled until all 3 filled; guessers tap; author can't guess; leaderboard updates; fields reset next round
- [ ] Act It Out: **Start 60 seconds** only on actor; **Got it / Skip** change the word; others never see the word; timer end → "Time!"
- [ ] Imposter: tap card to show/hide role; **Time to vote**; vote; reveal; points; role hidden again next round

## Known limits to expect
- Backgrounded iPhones get suspended; the reconnect logic is best-effort.
- Hard app blocking needs Apple's Family Controls approval.
