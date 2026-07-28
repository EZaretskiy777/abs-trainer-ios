# Exercise playback validation contract

## Scope

This contract covers bundled, muted `AVQueuePlayer` playback in Exercise Detail. It does not change production copy, controls, layout, fallback, Reduce Motion, or playback policy. The accessibility probe and its counters are compiled only under `DEBUG` and are emitted only when the process is launched with `-ValidationMode YES`.

Minimum target is iOS 16, the UI stack is SwiftUI with `VideoPlayer`, and the shared scheme is `AbsTrainer`.

## DEBUG probe

Accessibility identifier: `validation.exercisePlayback`.

The semicolon-delimited value is:

```text
state=<poster|loading|ready|playing|failed>;
states=<ordered transition history>;
loops=<owned AVPlayerLooper items that posted DidPlayToEnd>;
posterMs=<presentation start to poster onAppear, or -1>;
videoMs=<presentation start to first positive player time while timeControlStatus is playing, or -1>;
firstLoopMs=<media duration of the first completed looper item, or -1>;
interruptions=<playing to loading|ready|failed transitions>;
positionMs=<current player position>;
```

Required automated contract:

- `states` contains `poster,loading,ready,playing` in order;
- current `state` reaches `playing` only when `AVQueuePlayer.timeControlStatus == .playing` and player time is positive;
- `loops >= 1` and `firstLoopMs` is 3500...4500 for the validated four-second asset;
- `interruptions == 0` through the first loop;
- `posterMs >= 0`, `videoMs > 0`, and `videoMs >= posterMs`;
- failures expose `state=failed` rather than remaining in loading.

`posterMs` never creates its own clock origin. The parent establishes the presentation origin; if SwiftUI reports the child poster before the parent's `onAppear`, the probe records a pending poster event and resolves it to `0 ms` only when the independent parent origin starts, meaning the poster lifecycle event had already occurred by T0. `loops` increments only for a strongly-held item owned by this queue after `AVPlayerItemDidPlayToEndTime`; queue identity changes, setup, teardown, released-object identifier reuse, and unrelated players cannot increment it. `firstLoopMs` is read from that completed item's media timeline, so runner scheduling delay cannot make a valid four-second asset appear longer. A transition from actual playing to paused, waiting, loading, ready, or failed increments `interruptions`. This detects player-state regressions but cannot prove pixel luminance, so the CI screen recording remains the visual gate for a black-frame flash across the seam.

## Timing limitation and physical-device performance gate

The timestamps are monotonic process-uptime measurements and are useful observability, but GitHub-hosted Simulator startup latency is not a release-performance result. Simulator media decode and presentation share a virtualized macOS runner whose scheduling, decoder warm-up, host load, and display pipeline differ from physical iPhone hardware. Run 30327840932 on the hosted iOS 26.5 iPhone 17 Pro Max Simulator measured `posterMs=38` and `videoMs=1002`; this is a valid event trace but not a reliable supported-device measurement of the product's 500 ms target.

Simulator CI must collect and attach both timestamps, but it does not enforce the optical `posterMs <= 100` or `videoMs <= 500` performance targets. Both assertions remain active when the same UI test is compiled for a physical iOS target.

Before release, run this manual performance gate on the oldest supported physical iPhone available (prefer iPhone 8 on iOS 16; otherwise record the exact oldest device and OS used):

1. Install a fresh Debug validation build containing only bundled exercise media; disable Low Power Mode and Reduce Motion.
2. Reboot the device, wait two minutes, and keep it disconnected from Xcode except while collecting each result.
3. Start a 120 fps or 240 fps external-camera recording that includes the device display.
4. Cold-launch the app, open Exercise Library, then open `crunch`. Repeat ten times, terminating the app between trials.
5. For every trial, save the probe value after `loops >= 1`. In the external recording, use the first fully visible Detail chrome frame as T0, then count frames to the first visible poster and first moving video frame.
6. Inspect the poster-to-video transition and one complete seam; reject any blank/black frame, spinner relabelled as playback, freeze, or visible jump.

Pass criteria for every one of the ten trials:

- optical poster paint is at most 100 ms after T0;
- optical first moving local-video frame is at most 500 ms after T0;
- probe reaches ordered loading -> ready -> playing, reports one 3500...4500 ms loop, and reports zero interruptions;
- poster remains visible until the first video frame and no black-frame flash occurs.

Attach the raw high-frame-rate recordings, device/OS/build SHA, all ten probe strings, and a frame-count table. A Simulator result must never be substituted for this device gate.

## 320x568 compact coverage

The GitHub macOS 26 runner inventory used by run 30327840932 provided iOS 26.2/26.4/26.5 devices from iPhone 16e/17-class families and no iPhone SE-class Simulator. No iOS 16-capable Apple device has a native 320x568 point screen: the first-generation iPhone SE is 320x568 but cannot run the app's iOS 16 minimum.

Automation therefore launches on the available iPhone 17 Pro Max Simulator and constrains the validation root to exactly 320x568 points. The UI test asserts `validation.viewport.frame.width == 320` and `height == 568` before exercising playback and attaching screenshots. This is exact compact-layout coverage, but it does not emulate first-generation SE safe areas or hardware. Physical supported-device layout remains a separate manual check on iPhone 8/SE (2nd generation) class hardware at its native size.
