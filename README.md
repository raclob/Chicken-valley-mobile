# Chicken Valley Mobile

**[Download Android APK](https://github.com/raclob/Chicken-valley-mobile/releases/latest/download/chicken-valley.apk)** — tap this link on your Android phone, then open the downloaded `chicken-valley.apk` to install.

[Downloads and installation instructions](downloads/README.md) · [Latest release](https://github.com/raclob/Chicken-valley-mobile/releases/latest)

A mobile-first overhead farm rivalry game built with Godot 4.6.3. Grow chickens, build coops, improve defenses, and launch raids against an AI rival. The largest flock after four minutes wins.

## Play

Open `project.godot` in Godot and run the project. Play in landscape orientation. Both farms remain visible from above. Tap the bottom buttons to manage the farm; Hide actions clears space for watching. Pause stops the economy, raids, and wildlife.

## Mobile v0.2

- Farms are now 44 world units apart instead of 20.
- Three trails wind around rocks. Each match randomizes detours and trail surfaces: fast paths, normal trails, or slow mud. Raiders use these visible paths in both directions; boots improve travel speed. Each raid announces its outbound travel time.
- Fences enclose all four sides. Each upgrade adds visible rails and two seconds of gate delay. Raiders stop at the gate with a countdown before attempting theft.
- Defense blocks up to `ceil((2 × fence level + 2 × dogs) / (1 + 0.5 × expansions))` chickens per attack. The HUD shows the current block value. Fences and dogs also stop coyote losses. Coyotes approach visibly, then take up to three unprotected chickens.
- Sell one chicken for meat to receive 14 coins immediately. That chicken stops earning 0.65 coins per second from eggs. Buying costs 20 coins, so buying and immediately selling does not generate profit.
- Expand the farm twice, from a 12×12 plot to 16×16 and then 20×20. Each expansion unlocks two more coop plots (2, 4, then 6 coops), each holding 12 chickens. Larger farms spread existing defenses thinner.
- Buy up to six guard dogs. Dogs patrol the perimeter and contribute defense against raids and coyotes. Wildlife begins after 40 seconds, then approaches a randomly chosen farm every 35–55 seconds.
- The AI uses the same purchasing rules, including expansion and dogs. Winning still depends on the chickens remaining at the end; meat sales trade future income and flock score for immediate cash.

This version continues the farm economy from `raclob/Chicken-Valley` at commit `2475370df6d7a53fc3f17e71c2853a00a1aa5601`.

## Android

The Android prototype workflow runs tests, renders a preview, exports a debug-signed APK, and publishes it as a GitHub release. After the workflow succeeds, download `chicken-valley.apk` from the latest release. Package `org.chickenvalley.mobile` installs alongside the original prototype. Version code 2 identifies this update.

## Verification

Run `godot --headless --path . --script tests.gd` for economy, meat sales, capacity, defense coverage, fence delays, route speeds, coyote protection, raid delivery, final scoring, and five complete seeded AI matches. Run `godot --headless --path . --script mobile_tests.gd` for purchase controls, expanded farm visuals, route animation positions, coyote nodes, overhead framing, and pause. Run `godot --headless --path . --quit-after 120` for scene startup.

Gameplay tests, mobile scene checks, headless startup, preview rendering, Android APK export, and APK signature verification passed in GitHub Actions. The APK is published under Releases. Real-phone touch and installation testing remain pending. Graphics are procedural placeholders. Play is offline against AI.
