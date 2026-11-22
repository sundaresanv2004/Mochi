# Contributing to Mochi

Thanks for helping! Mochi is a small project, so the process is light.

## Setup

```bash
git clone <repo-url>
cd Mochi
swift build
swift run
```

You need macOS 13+ and a Swift 5.9+ toolchain, or Windows 10/11 with Swift 6.1+ (see the README's
Windows section).

Mochi builds for both from the same code. The pet's logic and drawing use AppKit on the Mac and
`AppKitLite` (`Sources/AppKitLite`) on Windows, which only has what Mochi uses. If you reach for an AppKit
API it doesn't have, add it to `AppKitLite`, or keep the code Mac-only with `#if os(macOS)`. Windows-only code
goes in `Sources/Mochi/Platform/Windows`, inside `#if os(Windows)`.

## Making changes

1. Fork the repo and create a branch (`feature/my-idea`).
2. Keep changes focused: one feature or fix per pull request.
3. Make sure `swift build` succeeds with no new warnings, and `swift run Mochi --logic-test` passes. The pull
   request checks build it on macOS and Windows.
4. If you changed how a pet looks, run `swift run Mochi --render preview.png` and attach the image to your PR
   (on Windows it draws the same sheets, handy for checking both look alike).
5. `swift run Mochi --system-test` prints what the pet can tell about the computer (idle time, typing, CPU,
   battery, the Dock or taskbar, the windows it could stand on).
6. Open a pull request describing what changed and why.

## Ideas that are easy to start with

- A new pet (`Pet/Model/Species.swift` + a drawing branch in `Pet/View/`)
- A new trick (`PetAction` in `Brain/Brain.swift`, handled in `PetController+Behavior.swift`)
- New lines for `Pet/Model/Dialogue.swift`

## Reporting bugs

Please include your macOS version, which pet you were using, and steps to reproduce. For
"the pet went somewhere weird" bugs, mention whether you use multiple monitors or a Dock on the side.
