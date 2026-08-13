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

> Today's daily run is live — the same planets for everyone. Tap, orbit, and see how you rank on this week's leaderboard.

## Description

```
One tap. Endless orbits. How far can you fly?

Orbit is a calm, glowing space arcade game built around a single move: tap to leave your orbit, fly straight, and get caught by the next planet's ring. Hit the core dead-center for a PERFECT and double points.

EASY TO START, HARD TO PUT DOWN
• Rings start big and forgiving, then shrink as you level up
• Orbits spin faster the deeper you go
• Infinite levels — every 20 planets is a new one

POWER-UP PLANETS
• Golden — worth double points
• Shield — survive one missed launch
• Magnet — widens the capture ring for your next hops
• Unstable — its ring shrinks while you orbit; extra points for the risk

BECOME A PILOT
• Every run earns permanent XP — level up your pilot
• Unlock new trail colors as you climb

DAILY CHALLENGE
• One seeded run per day — the same planets for everyone on Earth
• Unlimited retries all day
• Build a streak by playing every day

COMPETE WORLDWIDE
• Weekly, monthly, and all-time leaderboards
• No account, no password — just pick a name and play
• 20 avatars to choose from

A LIVING COSMOS
• Glowing neon planets, nebulae, and drifting space dust
• Comets, shooting stars, asteroids, and little rockets passing by
• Musical capture notes over a soft ambient soundtrack — respects your
  silent switch and never interrupts your own music
• Soft haptics that make every capture feel right

Classic mode works fully offline — perfect for the subway. Your best scores reach the leaderboard when you're back online.

One more run. You know you want to.
```

## Keywords (100 max, comma-separated)

```
planet,gravity,one tap,casual,offline,streak,galaxy,stars,hyper casual,reflex,timing,hop,flappy
```

(94 characters. Don't repeat words already in the name/subtitle — orbit, space, arcade, daily, leaderboard are indexed from there.)

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
