# Changelog

## Unreleased

- Debug page: a new Event log keeps the last 500 things the pets did and why, newest first. It shows each decision and what chose it (instincts, the AI model, a reminder, a menu command, music starting…), every line said or held back and why, each AI request with its prompt, reply and how long it took (and when the pet fell back to its built-in lines), sound changes, reminder clocks, focus sessions, two-pet meetings and conversations, falls, throws, display hops, and pausing while the Mac sleeps. Filter by kind, search, pause the list, expand an entry for details, and copy or save it as text for a bug report. Nothing is written to disk unless you save it
- Debug page: Live readings now show energy, tummy, joy and bond as numbers, with the levels at which the pet's mood changes, and the activity header reads in plain words ("Walk right on the floor")
- `Mochi --render` also draws the Debug page's Live readings and Event log, and `Mochi --logic-test` checks the event log

- Music: the pet no longer drops everything to dance when Spotify, Apple Music or another player starts. It keeps walking, climbing and exploring as usual while vibing to the beat: footsteps in time with the music, a side-to-side groove, foot taps and waving arms when it stands still, and a few seconds with its eyes closed, lost in the song. It still breaks into a proper dance now and then. Music playing during a call (for example Spotify while you sit in a Discord voice channel) gets the vibe too; the pet just stays quiet for the call

- AI (optional): connect any OpenAI-compatible server in Settings › AI, local (Ollama, LM Studio, llama.cpp) or hosted. The API key is kept in the keychain, and the pet falls back to its built-in lines and behaviour whenever the server is off or slow
- AI: fresh lines written by the model for every moment the pet speaks, in its own voice, generated in the background and saved
- AI: remarks about what is going on: music or a video starting (and in which app), you coming back, the time of day, the battery, a busy Mac, the end of a focus session
- AI: every few minutes the model chooses the pet's next move; the built-in instincts handle the rest
- AI: two pets have a short conversation when they meet to say hello, and now and then get together for a longer chat about you (what they remember, your day so far), what's going on, or pet life. The conversation is written first, so with a slow model they simply meet a little later
- AI: "Ask Mochi…" in the menu opens a text box for requests in plain words: tricks, treats, focus sessions, reminders, outfits, size, or a question
- AI: the pet remembers a few facts about you and writes a diary entry for each day (Settings › AI)
- `Mochi --ai-test <server> <model>` tries every AI feature once against a server and prints what came back
- Tough pets: a second, rougher drawing style with angular bodies, slanted eyes under heavy brows, fangs and claws, and no rosy cheeks
- Two new tough pets: Fang the wolf and Chomp the shark, each with its own personality, lines, snack, toy and power move
- Rex, Bolt and Ember are redrawn in the tough style: Rex has a toothy jaw, Bolt is a battle mech with a visor and chest reactor, Ember has spread wings and slit eyes
- The pet picker shows the five cute pets on the first row and the five tough ones on the second
- Settings redesigned: a sidebar of pages, a pet card with its mood, needs and actions, and grouped rows with coloured icons
- No more emoji in the menu bar or settings: the menu bar shows a paw glyph and moods use symbols (speech bubbles, treats and toys keep theirs)
- Smoother movement: pets ease in and out of a walk, rock and lean as they go, turn their head round instead of flipping, and squash when they land
- Two pets now do things together: they call each other down to the ground, then say hello, play tag, dance, play follow the leader, show off or nap side by side. Pet one and the other may run over wanting some too, and they no longer stand on the same spot
- Debug page in settings: fire any reminder on demand, watch each reminder's countdown, skip the clocks ahead, see what sound the pet detects and from which apps, and stage any two-pet meeting
- Reminders can be set to every 10 minutes, and the stretch break has its own interval instead of a fixed 50 minutes
- Fixed: reminders rarely fired, because every clock restarted after five minutes without input. They now keep counting while you read or watch, pause when you step away, and only start over after a 15-minute break
- Fixed: the pet acted as if music was playing when it wasn't. Sound from browsers and other apps is ignored unless you turn on "React to other sound too", and chat apps only count as a call while they use the microphone
- Multiple displays: the pet hops across where two displays touch side by side, now and then leaps to any other display, follows your cursor to the next one, and goes to find the second pet when they are on different displays
- Livelier: a pet that has not moved for 40 seconds (with no call, video, focus session or absence to explain it) gets up, wanders and says something. It no longer gets drowsy after three minutes without a click, and sulks less when hungry or lonely
- The Debug page shows what the pet is doing and why, which display it is on, and can send it to the next display
- Fixed: posture and stretch reminders were replaced by the pet's own "*yaaawn*" bubble about half the time
- Fixed: sitting in a Discord voice channel (or any open call) froze the pet and held every reminder back for as long as it lasted. On a call the pet now stays silent but keeps moving, and a due reminder waits at most five minutes. "Stay quiet during calls" can be switched off in Behavior
- `Mochi --logic-test` checks the reminder clocks, twenty simulated minutes of pet life and every two-pet meeting
- Fixed: spins, backflips and zoomies could start while hanging from the top of the screen or a wall, and an interrupted trick could leave the pet tilted

## 0.5.0

- Three new pets: Rex the dino, Bolt the robot and Ember the dragon, each with its own look, personality, lines, snack and toy
- Power moves: Ember breathes fire, Bolt crackles with lightning, Rex roars, Boo shouts "BOO!", and the others burst into stars (Interact › Power Move, and on their own now and then)
- Backflip added to the tricks
- New outfits: cap, shades and ninja headband
- Ball rallies are scored: the longer it goes, the likelier a miss, and the pet remembers your best rally
- Throw and bounce: let go of the pet mid-swing and it flies, tumbles, bounces off the screen edges and lands dizzy
- Second pet: switch on a companion in settings; the two run over to greet each other
- Hide and peek: the pet sneaks to a screen edge, ducks behind it and pops out when you come looking
- Outfits: flower, glasses, party hat, crown and halo unlock as your bond levels up
- Daily check-in: a Today tab with your day in numbers, a recap at 6 pm and the next morning, and "Daily Check-in" in the menu
- Gentle reminders: water, posture and eye-rest nudges at intervals you choose, alongside the stretch reminder
- Busy-Mac reactions: the pet sweats when the processor is flat out or the Mac runs hot, and shivers on a nearly empty battery
- Calendar alerts (optional, asks for permission): a heads-up five minutes before events and as they start
- Battery: everything stops while the Mac sleeps, the display is off or the screen is locked; a napping pet animates at 6 fps and a standing one at 15; window scans are cached and shared; settings previews stop when the window is closed
- `swift run` and the built app now share the same saved pet (older `swift run` data is carried over)
- Settings gained Reminders and Today tabs

## 0.4.0

- Pets have a brain now: energy, tummy and joy drift over time and steer what the pet does (naps when tired, sulks and asks for a snack when hungry, comes looking for you when lonely, extra bouncy when happy)
- Each pet has its own personality (Mochi naps a lot, Miso explores, Clover plays, Pip is always hungry, Boo barely sleeps)
- Bond: petting, treats, play and focus sessions grow your friendship through six levels; the pet remembers you between launches and misses you when you've been gone
- New sad pose for when the pet needs something
- Play ball: drop a toy and the pet chases it and kicks it around
- Focus sessions (15 / 25 / 50 minutes): the pet keeps quiet, then celebrates with you
- Launch at login (from the built Mochi.app)
- The menu and the settings panel show how the pet is feeling
- Smaller pet by default, with a Small / Medium / Large size setting
- Tidier menu: a compact status card, treat and play up top, the rest grouped under Interact and Focus Session
- Settings reorganized into three tabs: Pet, Behavior and General
- Typing reactions: the pet bops with each key press and cheers on long or fast typing streaks (it only counts key presses, never reads them, and needs no permission)
- Speech bubbles scale with the pet size
- Fix: the pet no longer floats above the screen bottom when the Dock is hidden but macOS still reserves its space
- Every pet redrawn to be cuter: chubbier bodies with soft shading, bigger sparkly eyes, rosier cheeks, tiny mouths with tongues, paws in front, plus a bow for Clover, a feather tuft and heart-shaped face for Pip, and a cream-tipped tail for Miso

## 0.3.0

- Miso the cat and Clover the bunny are back, so there are five pets to choose from
- Spotify and Apple Music only trigger dancing while a track is actually playing (an open but paused app no longer counts)
- Settings: pet picker is now a grid

## 0.2.0

- New pets: Pip the penguin and Boo the ghost (replacing the cat and bunny)
- Reacts to sound: headphones and dancing for music, quiet for calls, watching for videos
- Notices when you step away (sleeps) and come back; break reminders; battery and time-of-day comments
- Give a treat: a snack drops and the pet runs to eat it
- Hover reaction and getting dizzy when you shake the mouse at it
- Decides on its own to climb the screen edges; grip is much stronger and only slips after a long time
- Stable when swiping between Spaces
- Settings: toggles for media reactions, break reminders and system comments

## 0.1.0

First release.

- Three pets: Mochi (blob), Miso (cat), Clover (bunny), chosen from a settings panel
- Walks the Dock, climbs screen edges, hangs from the top, stands on and leaps onto windows
- Drag and drop: clings to edges or falls onto windows
- Tricks: stretch, spin, dance, look around, zoomies, sleep
- Eyes follow the cursor, chasing, petting with hearts
- Speech bubbles with random greetings and adjustable chattiness
- Menu bar controls, right-click menu and a "Bring back to screen" button
- Rule-based `Brain` interface ready for an AI brain
