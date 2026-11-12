# iOS bring-up

Base: MonZaMac's `develop` branch, which now includes Lumiose Online. It shares Apple Silicon's
ARM64 host, the native NVN-to-Metal backend, the offline and online start screen,
and the code for the Lumiose guest module and relay. Use the PC fork as a reference
for server compatibility and its native chat/menu controls.

## Launcher preview

On an Apple Silicon Mac with Xcode, CMake and Ninja:

```sh
tools/build_ios.sh                      # iPhone/iPad Simulator
tools/build_ios.sh iphoneos             # arm64 device bundle, needs provisioning
```

The script verifies the pinned SDL and FFmpeg archives and keeps dependencies
and app output under `build/ios`. The preview contains no game code or mod.
To install it in a booted simulator:

```sh
xcrun simctl install booted build/ios/iphonesimulator/app/MonZaMac.app
xcrun simctl launch booted com.monzamac.ios
```

To inspect the touch controls without game files, launch the simulator app with
`SIMCTL_CHILD_LARECOMP_TOUCH_PREVIEW=1` (terminate a running instance first):

```sh
SIMCTL_CHILD_LARECOMP_TOUCH_PREVIEW=1 xcrun simctl launch booted com.monzamac.ios
```

In gameplay, the overlay hides when a controller is connected. The gear stays
available to open the in-game settings.

## Private offline build (experimental)

Prepare your own v2.0.2 game and Mega Dimension DLC on the Mac using MonZaMac's
existing setup, so the resulting `extracted` folder has `exefs`, `romfs`, and
`romfs.bin`. Set up the generator Python environment per AGENTS.md in this
checkout. Cross-compile privately:

```sh
IOS_GAME_ROOT=/path/to/extracted tools/build_ios.sh iphoneos
```

The Mac translates the game's NSOs and links the ARM64 output into the executable
before device signing. The app checks both NSO build IDs and tries to reserve the
runtime's fixed guest address range before offering Play. Provision and sign the
app for your device, then use Finder File Sharing or Files to copy the same
`extracted` folder into MonZaMac's Documents and reopen the app. The app does
not need the original package dumps or keys on the phone. Never share or commit
this app, its inputs, or any generated output. A normal build without
`IOS_GAME_ROOT` restores the preview.

The device build and the static table link can be checked without a real game.
The iPhone 17 Pro accepted a 6 GiB window at the original module base with
Personal Team signing. The iOS runtime packs its host-managed regions into
the first GiB and gives the guest SDK the remaining 5 GiB for its alias region.
The kernel caps physical allocations at the guest's application memory budget
and rejects mappings outside the alias region. The runtime limits the SDK's
initial allocator reservation to 3.5 GiB and clears unmapped pages without
faulting in untouched memory. The main and SDK module bases stay the same,
so the port can reuse the generated code and patches. Set
`LARECOMP_IOS_BOOT_PROBE=1` in the launch environment to log whether the
reservation succeeded.

With the compact layout, smaller host thread stacks and the bundled open
font as a fallback, the private v2.0.2 build reached the game's offline language
selection screen on an iPhone 17 Pro. In-game controls, longer sessions, and
online play still need testing.

## Online milestone

Reuse the Mac's offline patch capture from `tools/lumiose/prepare.py`. Its
`--export-aot` option uses the usual preparation inputs and writes a private
`*-aot` folder under `--out` with the patched main/SDK C, matching module C,
module file, and input identity. Use an ignored output directory such as
`build/lumiose-prepared`.
Compile and sign the matched code with the iOS app, keeping separate offline and
online entry tables. Replace the desktop relaunch with the runtime's in-process
teardown/reboot, retain consent and build-ID checks, and start network access only
on an explicit online launch. A mod code update requires a new signed build.

Use a known compatible module in the first device test. Verify the relay handshake
and player visibility against a desktop client, then chat with the system
keyboard, controller and touch input, voice permissions, reconnect on resume,
and saves shared between offline and online sessions.
