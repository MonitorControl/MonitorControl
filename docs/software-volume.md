# Optional software volume

Some digital monitor outputs, including the Samsung Smart M80F tested in discussion #1077, do not expose a writable CoreAudio volume control and may not apply DDC volume commands. This opt-in backend attenuates the audio stream on the Mac; it does not change the monitor's internal volume or add DDC support.

## Use and compatibility

On macOS 15 or later, select the monitor as the default audio output and choose **Enable Software Volume for This Output…** in the MonitorControl menu. Confirm the explanation before macOS requests audio-capture authorization. The output name must match an external display for this initial integration. The slider and standard multimedia volume/mute keys then share the software gain. Disable the option to release the tap and restore the original audio path.

The feature is disabled by default. Availability guards retain existing behavior on older macOS versions without raising the project's deployment target. Building the backend requires a modern SDK with the Swift Synchronization module (Xcode 16 or later). A stereo floating-point render path is used; multichannel, encoded/protected audio and other formats need separate validation.

## Implementation

A device-scoped process tap excludes MonitorControl itself. A private aggregate combines that tap and the physical output on one output clock. An IOProc processes preallocated stereo buffers without allocations or locks in the render loop. Gain is the cube of the level, from zero to unity, with a 15 ms transition. The monitor's physical volume remains the upper limit.

The existing OSD, brightness controls, slider layout, signing, updater and application version remain unchanged. No driver, companion application, Logitech-specific reader or key remapping is introduced. The dedicated volume event tap uses `cgSessionEventTap`, passes playback keys through unchanged and is engaged only when the backend processes the selected output; normal native handling resumes on another output or when the backend stops. A 20 ms same-key filter coalesces duplicate press notifications observed locally, without suppressing regular volume-key repeat. Mute auto-repeat is ignored.

The backend stores its selected output UID, associated display preference identifier and software level. It pauses on another output, stops for sleep/quit and uses bounded recovery. The monotonic progress watchdog requires advancing frames only when another HAL client is actually playing to the output; idle or unknown activity does not exhaust retries.

## Attribution

Vendored audio-capture code is adapted from [CoreAudioTapKit](https://github.com/CJStanfield/CoreAudioTapKit), revision `aab395f1e8e5dd1bd369c3bbfcf5c6bdca85e099`, under MIT. Its license and revision are preserved in `MonitorControl/SoftwareAudio/Licenses` and copied into the app's resources.

## Validation

Run `bash Tests/run-software-audio-tests.sh` on macOS 15+ with the command-line tools. Tests cover gain bounds/NaN, stereo ramps to silence, duplicate key notifications, mute repeat, output matching and watchdog idle/stall/recovery states. They do not capture audio or request permissions.

The local prototype using the same audio backend was physically tested on Apple Silicon, macOS 27.2 beta, Samsung Smart M80F DisplayPort audio and Logitech MX Keys Mini/Bolt: brightness, volume up/down, mute/unmute and a fresh sign-out/sign-in worked. Traces showed duplicate media notifications 2–4 ms apart and one applied action per press after filtering. The cleaned integration in this PR is compiled and unit-tested separately; its availability facade and menu opt-in need maintainer review and additional runtime coverage. Sleep/wake, hotplug, output switching and broader device/format support are not claimed as tested.

### Playback-key regression check

In the local prototype, Spotify previous/next/play-pause keys failed while the volume interceptor used `cgAnnotatedSessionEventTap`. They worked with MonitorControl closed, and with its keyboard interceptors disabled while audio processing remained active. Moving only the dedicated volume interceptor to `cgSessionEventTap` restored Spotify playback keys and volume together, as confirmed by the user. No Spotify-specific commands, playback-key interception or Logitech remapping are added. This PR applies that same tap-location correction; the physical test was performed on the local prototype, not on a newly installed build of this cleaned PR.
