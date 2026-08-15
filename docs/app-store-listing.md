# Orbit — App Store listing

Everything to paste into App Store Connect.

## Basics

| Field | Value |
|---|---|
| Name (30 max) | `Orbit: One-Tap Space Arcade` |
| Subtitle (30 max) | `Daily runs & leaderboards` |
| Bundle ID | `online.foundry7.orbit` |
| Primary category | Games → Arcade |
| Secondary category | Games → Casual |
| Copyright | © 2026 Foundry7 |
| Privacy policy URL | https://almindurmis.github.io/orbit-ios/privacy.html |
| Support URL | https://foundry7.online |
| Marketing URL | https://foundry7.online |
| Price | Free (ad-supported) |

## Promotional text (170 max, editable anytime)

> Today's run is live — same planets, same walls, same gates for everyone. Race the top pilots' ghosts and see how far you fly.

## Description

```
One tap. Endless orbits. How far can you fly?

Orbit is a glowing space arcade game built around a single move: tap to leave
your orbit, fly straight, and get caught by the next planet's ring. Hit the
core dead-center for a PERFECT — chain them and your score multiplies up to x5
while your trail catches fire.

A GALAXY THAT FIGHTS BACK
• Sectors — every level is a named region with its own colors and sky
• Asteroid walls block the corridors; graze one for CLOSE CALL bonus points
• Bouncers ricochet your flight — bank shots are real
• Rotating gates guard planets; slip through the gap or don't pass at all
• Guardians — every 10th sector, a giant planet behind twin rotating gates

POWER-UP PLANETS
• Golden — double points · Shield — survive one miss
• Magnet — wider captures · Unstable — shrinking ring, extra points

RACE TODAY'S GHOSTS
• One seeded daily run — the same world for everyone on Earth
• Your best run and today's top pilots fly beside you as live ghosts
• Some days the whole world mutates: tiny rings, hyper orbits
• Build a streak by playing every day

THE WEEKLY GAUNTLET
• A brutal seeded run with hazards from the very first corridor
• Its own leaderboard — glory resets every Monday

BECOME A PILOT
• Permanent XP, pilot levels, and three fresh missions every day
• The Hangar: 6 ship looks and trail colors to unlock and combine
• Weekly, monthly, and all-time leaderboards — no account, just a name

RUN LAB
• Fly a friend's seed code: same planets, same walls, best score wins

ORBIT PREMIUM (optional subscription)
• No ads · one revive per run · Zen Drift · create your own challenge codes
• Full pilot stats · animated PRISM & EMBERS trails · a gold star on the
  leaderboard · double mission XP

A LIVING COSMOS
• Neon planets, nebulae, comets, shooting stars, and a deep-space soundtrack
  of metallic tones and sub-bass swells — it respects your silent switch

Classic mode works fully offline — perfect for the subway. Your best scores
reach the leaderboard when you're back online.

One more run. You know you want to.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://almindurmis.github.io/orbit-ios/privacy.html
```

> App Review 3.1.2: because the app sells auto-renewable subscriptions with the
> standard Apple EULA, the description MUST contain the EULA link above — it was
> a metadata rejection reason once (Aug 2026). Keep both links at the bottom of
> the description on every future edit.

## Keywords (100 max, comma-separated)

```
planet,gravity,one tap,casual,offline,streak,galaxy,ghost,hyper casual,reflex,dodge,boss,flappy
```

(95 characters. Don't repeat words already in the name/subtitle — orbit, space,
arcade, daily, leaderboard are indexed from there. "ghost", "dodge" and "boss"
replace the weaker "stars", "timing" and "hop" now that racing ghosts, hazards
and guardians are core features.)

## What's New (v1.1.0)

```
The galaxy just got dangerous — and a lot more beautiful.

• SECTORS — every level is now a named sector with its own colors and sky
• ASTEROID WALLS — glowing rock barriers block parts of the corridor; graze
  them for CLOSE CALL bonus points
• BOUNCERS — springy orbs that ricochet your flight; bank shots are real
• ROTATING GATES — orbiting shield arcs you must slip through
• PERFECT STREAKS — consecutive dead-center captures multiply your score up
  to ×5, with a flame trail that grows as your combo burns
• DAILY MISSIONS — three fresh goals every day, each paying pilot XP
• New pilot hub menu and a full run-summary screen with your distance to
  your best, longest streak, and mission rewards
• THE HANGAR — tap your pilot card to customize your orbiter: 6 ship looks
  and 7 trail colors, unlocked as your pilot level climbs
• A darker, deep-space soundtrack — metallic tones, sub-bass swells and an
  ominous ambient drone (the piano lesson is over)
• GHOST RACING — the daily challenge now replays your best run and today's
  top pilots as live ghosts flying beside you
• WEEKLY GAUNTLET — a brutal seeded run with hazards from the first corridor
  and its own leaderboard
• GUARDIANS — every 10th sector is defended by a giant planet behind twin
  rotating gates; bring it down for a heavy bonus
• DAILY TWISTS — some days the whole world mutates: tiny rings, hyper orbits
• RUN LAB — fly a friend's seed code: same planets, same walls, best score wins
• ORBIT PREMIUM — ad-free, one revive per run, Zen Drift, create your own
  challenge codes, full pilot stats, animated PRISM & EMBERS trails, a gold
  star on the leaderboard and double mission XP
```

## What's New (v1.0.1)

```
Your journey to becoming a space pilot starts here!

• POWER-UP PLANETS — Golden planets are worth double, Shields save you from
  one missed launch, Magnets widen your capture ring, and Unstable planets
  shrink while you orbit for bonus points
• PILOT PROGRESSION — every run now earns permanent XP; level up your pilot
  and unlock new trail colors
• SOUND — musical capture notes over a soft ambient soundtrack (respects your
  silent switch and never interrupts your own music)
• Leaderboards now open right at your rank and scroll smoothly in both
  directions, however big the board gets
• Fresh menu polish — clearer buttons and a rounded MENU pill
```

## What's New (v1.0)

> First launch! Tap between glowing orbits, take on the daily challenge, and climb the worldwide leaderboards.

## Screenshots

6.9" (1320×2868) captured from the iPhone 16 Pro Max simulator via the
`OrbitUITests` screenshot test:

```sh
xcodebuild test -project Orbit.xcodeproj -scheme Orbit \
  -destination 'name=iPhone 16 Pro Max' CODE_SIGNING_ALLOWED=NO \
  -resultBundlePath shots.xcresult -only-testing:OrbitUITests
xcrun xcresulttool export attachments --path shots.xcresult --output-path screenshots/
```

Upload 6.9" only — App Store Connect scales the smaller sizes automatically.

## App Privacy answers (summary)

- **Identifiers → Device ID**: collected, linked to user (leaderboard account), not used for tracking
- **Identifiers → Advertising ID (IDFA)**: collected by AdMob, **used for tracking** (only when ATT granted)
- **User Content → Other (nickname)**: collected, linked to user
- **Usage Data → Advertising data**: collected by AdMob, not linked (per Google's current disclosure)
- Third-party SDKs: Google AdMob, Firebase Firestore

## Age rating

No objectionable content; contains ads. Expected rating: 4+ (or 9+ if the
questionnaire's ad-related questions push it there — either is fine).
