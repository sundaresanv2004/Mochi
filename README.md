# Mochi 🍡

A tiny desktop pet for macOS and Windows. Pick one of ten pets, five cute and five tough, and it lives on your screen: it wanders along the Dock,
climbs the screen edges, hangs from the top, stands on your windows, says hi, and reacts when you
click, drag or ignore it.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20Windows%2010%2F11-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-blue)

![The pets in different moods](docs/pets.png)

Each pet has a little mind of its own: it gets tired, hungry and lonely, has its own personality, and
grows closer to you the more you look after it. There is no AI model involved. Everything is rule-based
and runs offline, but the pet's decisions go through a single `Brain` interface, so a smarter
(LLM-powered) brain can be plugged in later without touching the rest.

## Pets

| Pet | Personality |
| --- | --- |
| **Mochi** 🍡 | Squishy and sleepy blob with a leaf sprout. Naps a lot and loves company |
| **Miso** 🐱 | Curious, sneaky cat with a wagging tail and whiskers. Explores and climbs, not very clingy |
| **Clover** 🐰 | Bouncy bunny with a pink bow whose ears flop when it sleeps. The most playful of the lot |
| **Pip** 🐧 | Waddly, dapper penguin with a feather tuft and a red scarf who flaps when happy. Always hungry |
| **Boo** 👻 | Floaty, friendly ghost with a wavy hem. Barely sleeps or eats |
| **Rex** 🦖 | Stompy, fierce dino with a big toothy jaw, heavy brows, orange head plates and famously tiny arms. Always hungry, loves to roar |
| **Bolt** 🤖 | Armoured battle mech with a scowling visor, a glowing chest reactor and a warning light. Curious and almost never sleeps |
| **Ember** 🐲 | Fiery, fearless dragon with spread wings, horns, slit eyes and a flame on its tail. The most playful of all |
| **Fang** 🐺 | Lone, scarred wolf with yellow eyes and bared fangs. Curious, not cuddly, howls for its power move |
| **Chomp** 🦈 | Shark that is all teeth, with a notched fin and flat black eyes. Barely sleeps and is always hungry |

Switch pets any time from the Pet tab in settings:

![Settings panel](docs/settings.png)

## Features

**Has a mind of its own**
- **Needs**: energy, tummy and joy drift over time. A tired pet naps, a hungry one sulks and asks for its favourite snack, a lonely one comes looking for you, and a happy one dances and gets the zoomies
- **Personality**: every pet weighs its choices differently (see the table above)
- **Bond**: petting, treats, playing and focus sessions grow your friendship from *New friend* to *Soulmate*; closer pets follow you more and say fonder things
- **Memory**: it remembers all of this between launches, rests while the app is closed, and misses you when you've been gone
- See how it's doing at the top of the menu and in the settings panel

**Can think with a language model (optional)**

Point Mochi at any server that speaks the OpenAI API (Ollama, LM Studio, llama.cpp, OpenRouter, OpenAI…) in
**Settings › AI**. Everything below is optional, each part has its own switch, and the pet falls back to its
built-in lines and behaviour whenever the server is off or slow.
- **Fresh lines**: the model writes new things to say for every moment (being petted, falling off a wall, a treat landing), in your pet's own voice. They are written in the background and saved, so bubbles stay instant
- **Remarks about what's going on**: music starting in Spotify, you coming back, lunch time, a low battery, a busy Mac
- **Decides what to do**: every few minutes the model picks the pet's next move from what it can do right now; in between, the pet follows its instincts
- **Two pets talk**: now and then they get together for a chat, mostly about you: your habits and likes, how your day is going, what's playing, or just snacks and naps. They also chat when they meet to say hello
- **Ask your pet**: *Ask Mochi…* in the menu opens a text box. "Dance", "25 minute focus", "remind me to drink water every 30 minutes", "put on the cap", "remember that I like lo-fi", or just a question
- **Memory and diary**: it keeps a few facts about you and writes a short diary entry for each day, which you can read in Settings › AI

With a local server nothing leaves your Mac. With a hosted one, short prompts are sent to it: the pet's mood, the
time, the name of the app playing sound, your daily counts, what it remembers and what you type in Ask. Never your
keystrokes, your screen or your calendar.

**Plays with you (and with a friend)**
- **Throw and bounce**: let go of the pet mid-swing and it flies, tumbles, bounces off the screen edges and lands dizzy
- **Second pet**: turn on a companion in settings and the two meet up to say hello, play tag, dance, follow each other, show off or nap side by side
- **Hide and peek**: it sneaks to a screen edge, ducks behind it and pops out when your cursor comes looking
- **Outfits**: a flower, a cap, glasses, shades, a party hat, a ninja headband, a crown and a halo unlock as your bond levels up
- **Power moves**: every pet has a signature move. Ember breathes fire, Bolt crackles with lightning, Rex roars
- **Ball rallies**: playing ball is scored. The longer the rally, the likelier a miss, and the pet remembers your record

**Looks after you**
- **Gentle reminders**: water, posture and eye-rest nudges at intervals you choose, plus a stretch after 50 minutes of work. They count time you are actually at your Mac and wait for calls and focus sessions to end
- **Daily check-in**: a Today tab with your day in numbers (time at the Mac, typing, focus sessions, breaks), and a recap at 6 pm and the next morning
- **Calendar alerts** (optional): a heads-up five minutes before an event and as it starts. This is the only feature that asks for a permission
- **Google Calendar** (optional): sign in from Settings › Reminders and the pet reads out each event's own notifications when they fall due (10 minutes before, 30 minutes before, a day before… whatever is set in Google Calendar, or the calendar's defaults), plus a "starting now" if you like. It syncs every five minutes with read-only access, skips declined and cancelled events, and catches up on a reminder missed while the Mac was asleep. The sign-in is kept in the Keychain and event titles are never sent to the AI server. You need an OAuth client of type *Desktop app* from Google Cloud Console with the Google Calendar API turned on: paste its ID and secret in Settings, or build the app with them (below) so nobody has to

**Moves around your whole screen**
- Walks the Dock, **climbs the left and right edges**, crawls along the top, and comes back down
- Sometimes decides on its own to head for an edge and climb; its grip is strong, but after a long time hanging around it may slip and fall
- Stands on top of your windows (and follows them), leaps up onto windows and hops off their edges
- Drag and drop: let go near a screen edge and it clings there; let go mid-screen and it falls onto a window or the Dock
- Stays stable when you swipe between Spaces and shows up over full-screen apps
- **Several displays**: hops across to the next display, follows your cursor there, and can be dragged anywhere

**Reacts to what is happening on your Mac** (no special permissions)
- **Whatever is playing**, from what your Mac shows as Now Playing (the media controls in Control Center): it starts within a moment of you pressing play, stops within a second of pausing, and isn't fooled by apps that just keep the speakers open, like dictation tools or an idle browser tab. For each kind of thing the pet has five acts; it picks one when something starts and switches every few minutes (and sometimes on a new song), so it never looks the same for long:
  - **Music** (Spotify, Apple Music, YouTube Music, a music video, ...): DJ at a turntable, air guitar, karaoke with eyes closed for the big notes, a glow-stick rave with the colours washing over it, or bongos. It vibes along to the beat whatever it's doing, and now and then breaks into a proper dance
  - **Podcasts and audiobooks**: one earbud in nodding along, taking notes (with the odd bright idea 💡), a coffee break, a little retro radio it leans in to, or deep thinking with a "?" turning into a "!". Calm, no dancing
  - **Videos** (YouTube and other sites): binge-watching on a phone, a bowl of chips, holding up a big 👍, pressing SUBSCRIBE and ringing the bell, or typing comments on a laptop ("first!"). The screen's light flickers on its face and is reflected in its eyes, and it giggles now and then
  - **Films and shows** (Netflix, Prime Video, the TV app, IINA, ...): 3D glasses and popcorn, wrapped up in a blanket, soda and nachos, hiding behind a cushion at the scary bits, or a tearjerker with tissues. Quiet and still until the credits
- **Calls** (Zoom, Teams, FaceTime, Discord, ...): goes quiet, but keeps watching or listening along to whatever is playing
- **Anything else making sound** (games, etc.): only if your Mac can't report Now Playing and you switch on "React to other audio"
- **Typing**: bops along with every key you press and cheers when you're on a roll or typing fast. It only reads the system's running count of key presses, never which keys
- Falls asleep when you step away, and welcomes you back when you return
- **Busy Mac**: sweats when the processor is flat out or the Mac runs hot, and shivers when the battery is nearly empty
- Comments on low battery, plugging in and mealtimes

<details>
<summary>See every act on every pet</summary>

**Music**: DJ, air guitar, karaoke, glow-stick rave, bongos

![Music acts](docs/acts-music.png)

**Podcasts and audiobooks**: earbud nodder, note-taker, coffee break, retro radio, deep thinker

![Podcast acts](docs/acts-podcast.png)

**Videos**: phone binge, snack attack, smash that like, subscribe bell, comment typer

![Video acts](docs/acts-video.png)

**Films and shows**: 3D cinema, blanket burrito, soda and nachos, scary scene, tearjerker

![Film acts](docs/acts-movie.png)

</details>

**Interacts with you**
- Eyes follow your cursor; it sometimes chases it and looks at you when you are near
- Click to pet it (hearts!), click fast to make it blush, poke it while it sleeps
- Hover over it for a moment and it perks up
- **Give a treat**: a snack drops from the top of the screen and the pet runs over to eat it
- **Play ball**: drop a toy and the pet chases it along the Dock and kicks it back into the air
- **Focus session** (15, 25 or 50 minutes): the pet keeps quiet and calm while you work, then celebrates with you
- **Shake your mouse** at it and it gets dizzy
- Tricks: yawn and stretch, spin, backflip, dance, look around, zoomies, power move, nap
- Speech bubbles: random hellos, time-of-day greetings and pet-specific lines (Silent / Quiet / Normal / Chatty)
- **Bring back to screen** button in case it ever wanders off
- **Launch at login** (when run from the built `Mochi.app`)
- **Three sizes**: Small, Medium (default) and Large

Lightweight: native Swift and AppKit, no dependencies, no Dock icon. Easy on the battery too: nothing runs
while the Mac sleeps, the display is off or the screen is locked, and the pet animates more slowly when it
is napping or just standing around.

## Requirements

- macOS 13 (Ventura) or later, with a Swift 5.9+ toolchain (Xcode 15+ or the Command Line Tools)
- or Windows 10 / 11 (64-bit), with the Swift toolchain (6.1+) and Visual Studio's C++ build tools to build it.
  The packaged app needs nothing installed

## Run it

```bash
git clone <repo-url>
cd Mochi
swift run
```

Or build a double-clickable app:

```bash
./scripts/build-app.sh
open dist/Mochi.app
```

To build the app with Google Calendar sign-in ready to use, pass your OAuth client in the environment.
They go into the built app only, never into the repo (don't put them in `Support/Info.plist`, which is committed):

```bash
GOOGLE_CLIENT_ID=… GOOGLE_CLIENT_SECRET=… ./scripts/build-app.sh
```

Without them (and with `swift run`), Settings › Reminders asks for your own OAuth client instead.

The build is ad-hoc signed, so on first launch macOS may ask you to right-click the app and choose
**Open**. Mochi lives in the menu bar (the icon matches your pet); there is no Dock icon.

## Windows

Download `Mochi-<version>-windows.zip` (or build it, below), unzip it anywhere and run `Mochi.exe`. The pet walks
along the top of the taskbar, and its icon sits in the notification area (bottom right; Windows 11 puts new
icons behind the **^** arrow until you drag them onto the taskbar). Click it, or right-click the pet, for the menu.

To build it, install Swift (`winget install --id Swift.Toolchain -e`, which also needs Visual Studio or its Build
Tools with the "Desktop development with C++" workload), then in PowerShell:

```powershell
git clone <repo-url>
cd Mochi
swift build
.build\debug\Mochi.exe               # or: swift run
.\scripts\build-windows.ps1          # dist\Mochi\Mochi.exe and dist\Mochi-<version>-windows.zip
```

`$env:GOOGLE_CLIENT_ID = "…"; $env:GOOGLE_CLIENT_SECRET = "…"; .\scripts\build-windows.ps1` builds it with a Google OAuth
client (into `Mochi.config.json` next to `Mochi.exe`, never into the repo).

Everything works the same as on the Mac, with these differences:

- **Settings** open in your web browser: a page served by Mochi itself on `127.0.0.1` only, with a key that changes
  every launch, so nothing else can reach it
- **What's playing** comes from the Windows media controls (the media flyout), read by a small PowerShell helper
  with no window; **calls** from the microphone privacy record (a chat app with the microphone on)
- **Calendar alerts** from a local calendar aren't available (Windows only lets packaged apps read it);
  **Google Calendar** works. Secrets (the AI key, the Google sign-in) go in Windows Credential Manager
- **Launch at login** uses the per-user Run key (Settings › General, or Settings › Apps › Startup in Windows)
- The pet runs on every display at the primary display's scale, so on a second display with a different scale
  it looks a little bigger or smaller

If `swift build` fails with "Invalid manifest" or a Swift program exits straight away with `0xC00004BC`, a folder
on your `PATH` is a junction (scoop's `…\current`, Oracle's `javapath`), which Windows won't search for DLLs
through: put Swift's runtime folder (`%LOCALAPPDATA%\Programs\Swift\Runtimes\<version>\usr\bin`) first on `PATH`.
`build-windows.ps1` does this for itself.

## Releasing

Push a version tag and GitHub Actions builds `Mochi-<version>.dmg` (macOS) and `Mochi-<version>-windows.zip`
(Windows) and publishes them as a GitHub Release (`.github/workflows/release.yml`):

```bash
git tag v0.6.0 && git push origin v0.6.0
```

A version with a dash (`v0.6.0-beta1`) becomes a pre-release. You can also start one from Actions › Release ›
Run workflow. Add `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` as repository secrets to build releases with
Google Calendar sign-in ready to use.

## Controls

| Action | What happens |
| --- | --- |
| Click the pet | Pets it (hearts and a happy hop) |
| Drag and drop | Pick it up; let go near an edge to make it cling |
| Right-click the pet or click the menu bar icon (the tray icon on Windows) | A status card, then Give a Treat, Play Ball, Interact (say hi, pet, come here, trick, sleep), Focus Session, Bring Back, Settings, Quit |
| Settings | **Pet**: choose a pet and see how it's doing. **Behavior**: what it's allowed to do and react to. **Reminders**: nudges, calendar alerts, daily check-in. **Today**: your day in numbers. **General**: size, speech bubbles, launch at login |
| `⌘ ,` / `⌘ B` (menu open) | Open settings / bring the pet back |

## How it works

The pet's position is tracked as the centre of a small transparent, borderless, always-on-top window.
Each tick (30 fps) it is attached to a **surface**: the floor (Dock or a window top), a side wall, the
ceiling, or in the air (falling). Walking along a surface and turning corners is handled in
`PetController`. Window tops are found with `CGWindowListCopyWindowInfo`, which only reads window
frames, so no Screen Recording or Accessibility permission is needed.

**On Windows** the same code runs unchanged on top of `AppKitLite` (`Sources/AppKitLite`), a small stand-in
for the parts of AppKit and Combine that Mochi uses, compiled only on Windows: layered (per-pixel
transparent) windows, displays and the cursor in AppKit's coordinates, `NSBezierPath`, colours, gradients and
text drawn with Direct2D and DirectWrite (`Sources/LiteCanvas`, a little C++), menus, the tray icon and a
message loop that also runs Foundation's run loop. The few things that differ by platform live in
`Sources/Mochi/Platform/Windows` (`WindowsApp` is the Windows `AppDelegate`). Window tops come from
`EnumWindows` and the taskbar from `Shell_TrayWnd`, again without any permission.

```
Sources/Mochi
├── App/
│   ├── main.swift                 entry point
│   ├── AppDelegate.swift          menu bar + right-click menu (macOS)
│   └── LoginItem.swift            launch at login (macOS)
├── Pet/
│   ├── Controller/                the pet's window, 30fps loop and everything it does
│   │   ├── PetController.swift    state, setup, start/stop
│   │   ├── +Commands              treats, ball, tricks, focus sessions (menu actions)
│   │   ├── +Tick                  the per-frame update
│   │   ├── +Behavior              applying the brain's decisions, speech
│   │   ├── +Movement              walking surfaces, corners, hide and peek, visiting the buddy
│   │   ├── +Physics               falling, landing, leaping, slipping, dragging, throwing
│   │   ├── +Geometry              screen frame, Dock, window platforms
│   │   ├── +Awareness             idle, battery, load, reminders, calendar
│   │   ├── +Media                 reacting to music, podcasts, videos, films and calls
│   │   ├── +AI                    remarks, typed requests, two-pet conversations
│   │   ├── +Input                 cursor shake / hover, typing along
│   │   ├── +Toys                  treat and ball handling
│   │   └── +Power                 adaptive frame rate, pause/resume
│   ├── View/                      Core Graphics drawing for every pet and mood
│   │   ├── PetView.swift          state, animation clock, mouse input, draw()
│   │   ├── +Body                  body shape, squash, shading
│   │   ├── +Parts                 ears, tails, limbs (Mochi, Miso, Clover, Pip, Boo)
│   │   ├── +Tough                 Rex, Bolt, Ember, Fang and Chomp
│   │   ├── +Face                  eyes, mouths, eyewear
│   │   ├── +Outfits               things worn on the head
│   │   ├── +Power                 power-move effects
│   │   ├── +Effects               sweat, headphones, Zs, notes, hearts
│   │   ├── +Media                 the screen's glow and its reflection in the eyes
│   │   └── Acts/                  the 20 things it does while something plays: +ActKit (shared helpers),
│   │                              +MusicActs, +PodcastActs, +VideoActs, +MovieActs
│   └── Model/
│       ├── Species.swift          pet definitions (colours, speed, lines)
│       ├── Outfit.swift           things to wear and the bond level that unlocks each
│       ├── MediaAct.swift         the acts for each kind of media, and how one is picked
│       ├── Dialogue.swift         everything the pet says
│       └── Dialogue+Media.swift   what it says about songs, podcasts, videos and films
├── Brain/
│   ├── Brain.swift                PetAction, Brain protocol, MindBrain (the built-in instincts)
│   └── Mind.swift                 needs, bond and memory (saved between launches)
├── AI/
│   ├── LLMClient.swift            OpenAI-compatible chat client, reply clean-up, keychain
│   ├── PetAI.swift                every prompt: lines, remarks, decisions, banter, requests, diary
│   ├── LLMBrain.swift             MindBrain with the model chiming in every few minutes
│   └── PetMemory.swift            remembered facts and the diary (Application Support/Mochi)
├── System/
│   ├── Platform.swift             finds window tops to stand on
│   ├── AudioWatcher.swift         what kind of sound is playing (music / video / call)
│   ├── NowPlaying.swift           what the system's Now Playing says is playing, and whether it's paused
│   ├── MediaClassifier.swift      is it a song, a podcast, a film or a video?
│   ├── SystemInfo.swift           idle time, battery, processor load, key press count
│   └── CalendarWatcher.swift      upcoming events (only if calendar alerts are on)
├── Features/
│   ├── Treat.swift                the snack and the ball you can drop
│   └── DayStats.swift             today's and yesterday's numbers for the check-in
├── UI/
│   ├── SpeechBubble.swift         the speech bubble window
│   ├── AskPanel.swift             the text box for typing to the pet
│   ├── Menu/MenuHeader.swift      status card at the top of the menu
│   ├── Components/                PetPreview, PetCard, SettingsKit (cards, rows, pills), Meter, StatTile
│   └── Settings/
│       ├── PetSettings.swift      saved preferences (UserDefaults)
│       ├── SettingsView.swift     the tabbed settings panel
│       ├── SettingsWindowController.swift
│       └── Tabs/                  Pet, Behavior, Reminders, Today, AI, General, Debug
└── Tools/
    ├── Render.swift               `Mochi --render out.png` writes a preview sheet
    ├── LogicTest.swift            `Mochi --logic-test`
    └── AITest.swift               `Mochi --ai-test <server> <model>` tries every AI feature once
```

## Make it your own

**Add a new pet:** add a case to `Species` (name, colours, speed, lines), then add its drawing branch in
`Pet/View/` (`PetView+Body` for the shape, `+Parts`/`+Creatures` for limbs, `+Face` for face extras). Check how it looks without running the app:

```bash
swift run Mochi --render preview.png
```

**Add a new action:** add a case to `PetAction` in `Brain.swift`, give it a weight in `MindBrain`, and handle it in
`PetController.behave` (`Pet/Controller/PetController+Behavior.swift`) (and a `Mood` in `PetView` if it needs a new pose).

**Change how the AI talks:** every prompt lives in `AI/PetAI.swift` (the pet's character is `persona`). New moments
for the model to write lines for go in `Dialogue.moments`. Try your changes against your own server:

```bash
swift run Mochi --ai-test http://localhost:11434/v1 llama3.2
```

**Swap the brain:** anything that implements `Brain` can drive the pet; pass it to `PetController(brain:)`.
`LLMBrain` is the default and behaves exactly like `MindBrain` while AI is off.

## Roadmap

- [x] AI brain that talks and decides what to do (any OpenAI-compatible server)
- [ ] A back-and-forth chat window
- [ ] Real beat detection (needs audio-capture permission)
- [ ] More pets and more tricks
- [ ] Multi-monitor roaming
- [x] Windows
- [ ] Windows: per-display scale, local calendar alerts

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
