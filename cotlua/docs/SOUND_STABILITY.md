# Sound-manager crash mitigation

Source: [Blizzard forum report, October 9, 2026](https://us.forums.blizzard.com/en/warcraft3/t/crash-critical-error-sometimes-caused-by-stopsound-native/39720).

The report concerns Warcraft III 3.0.0 build 24268: an intermittent sound-manager
access violation reached through `StopSound(sound, false, false)`. The author
suspects prior corruption of an internal sound-instance list and does not
identify a reproducible cause or confirm a map-side workaround. The proposed
memory/list-management fixes require engine changes, outside this map's Lua.

## Applied map change

`ui/dialogs/stat_allocation.lua` had the same repeated stop/start pattern for
cached click, apply and error sounds. It now checks `GetSoundIsPlaying` and starts
a sound only when it is idle. Playing feedback is allowed to finish naturally;
there is no forced stop or restart. This matches the existing shop feedback.
Sound handles remain allocated once on every client at initialization. Playback
and its playing-state check remain local to the intended player; UI callbacks
create no new sound handles and native audio state never controls gameplay.

This is a precaution that removes exposure to the reported repeated-stop path,
not a verified repair of the engine's suspected list corruption.

## Remaining sound lifetimes

All executable Lua `StopSound` sites were reviewed. Four remain, all with
`killWhenDone=true`: two startup calls disable Warcraft's default day/night
ambience, and two ALICE movement-sound cleanup paths dispose looping effects
(after optional volume fade). None is followed by restarting the same sound.
Removing these stops or merely muting the loops would leave unwanted playback
or sound instances alive. They are retained as intentional lifecycle operations.

`SoundHandler` creates one-shot sounds and calls `KillSoundWhenDone`. The report
also mentions that pattern but does not establish it as the cause, so this
change does not replace it with another unproven sound lifetime mechanism.

## Verification

`test_stat_allocation_ui.lua` executes the real callbacks with `StopSound` made
fatal. Rapid clicks must not restart active feedback; simulated completion
allows replay. Existing checks cover owner-only playback, Apply feedback and
fixed sound-handle allocation. Engine crash avoidance still requires extended
in-game validation; the original intermittent crash cannot be proven absent
by offline mocks. No beta packaging is part of this change.
