# Capturable facility controls — 13 October 2026

The real Sites overview passed rendered verification at **1280 × 720 and 150% interface scale**, in **English and Chinese**, with **0 failures**. The test uses actual PointOfInterest nodes and existing building models on Expanded Desert Frontier. No UI source fixes were needed. The same flow was rerun after the final capture-status/world-label localization and service-catalog filtering, again with 0 failures; the images and raw log reflect that rerun.

Mouse motion, clicks, wheel events and keyboard presses travel through the engine's normal Window.push_input routing. Buttons are not activated by directly invoking their callbacks. The capture fixture places a real infantry unit in the camp's ring and then allows ten seconds of ordinary physics simulation to claim it.

Verified behavior:

- Clicking the actual Sites button opens the six-card overview and pauses the running match; Back receives keyboard focus.
- Every card's labels and buttons can be scrolled fully into the viewport. Engine mouse-wheel input moves the list. Neutral recruitment and cancellation stay disabled, and clicks on disabled recruitment leave funds and queue unchanged.
- Opening Sites cancels an armed attack-move command. Keyboard attack-move inside the modal, clicking View, and activating Back with Enter leave selected infantry orders unchanged.
- After real infantry capture, an engine-routed Hire click queues a paid contract and debits the displayed price. Cancel returns the exact amount and releases the queued contract. A subsequent paid hire completes and produces an actual infantry unit after View resumes simulation.
- View centers the camera on the camp and restores the previous pause state. Enter on focused Back also restores both running and already-paused states; a previously paused match's simulation clock remains unchanged.
- Chinese title, statuses, recruitment captions and controls render correctly; the source models remain in the established art style.

The six images show neutral overview, a paid contract, and the captured camp with its recruit in both locales. The raw log records native window size, logical viewport size, interface factor and rendered texture dimensions to prove the requested configuration.

Reproduce:

```sh
tmp/tooling/godot-4.6/Godot.app/Contents/MacOS/Godot --path . --windowed --resolution 1280x720 --script res://tests/rendered/PointOfInterestPreview.gd
```

The harness waits for native fullscreen/window transitions using wall time before setting the capture resolution. Input is injected through the Godot engine; this run does not claim physical operating-system mouse or keyboard automation. Combat balance, ownership transfer, service repair, and save/restore are covered by the separate headless facility checks.
