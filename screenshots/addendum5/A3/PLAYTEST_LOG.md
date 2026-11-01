# A3 playtest log (2026-11-01, Studio Play, numbers only)

Studio's 3D view was still frozen (viewport 1x1, RenderStepped 0/s, Heartbeat 60/s), so no screenshots.
`footprint.svg` (this folder) is a top-down drawing of the new lane made from the Config numbers.

## Server at start
- `SkylineLanes.SharedLane` built: 60 spot models (`Lane1`..`Lane60`), 106 visual parts, `Ready = true`.
- `ServerStorage.A5OldLanes` holds the 26 moved things (Lane1-6, LaneLines, Design.lanes lane_1-6, divider_1-5
  + gold caps, ball_return_1-3). Edit mode still has them in place (runtime-only move).
- Player got spot 6 (middle first), stands at (-40.5, 853.6, -3444) on its ring, character parts in `SL_Players`.
  Floor sign: "6 · EFARES".
- Collision groups: SL_PinView vs SL_Players = false, SL_PinView vs Default = true, SL_Balls vs everything = false.
- Hand-out order: 6, 7, 5, 8, 4, 9, 3, 10, 2, 11, 1, 12, then 18, 19 ... (half a spot over), spot 60 at z -3438.

## Client
- Racks drawn: 1 (on spot 6), 40 pins, pin parts in SL_PinView. YOUR SPOT glow + tag on spot 6 only.
- 4 throws: counts 6, 7, 6, 7, bag 0 -> 60 (full). Own rack: 40 standing, knocked pins flying as debris.
- SELL teleport, then 3 more throws while a FAKE second thrower (spots 5, 7 and 8, UserId 999, Sonic Boom,
  3,200 pins, 60 results a second, light results with no pin list) ran: 207 fake results arrived, at most 8 plain
  balls on screen at once (cap 8), still 1 rack drawn, own rack untouched (40 standing), own bag only changed by
  own throws. Spot 7 had ReadyAt 100 s in the future; spot 6 throws were still accepted (cooldown per player).
- Standing on spot 9 (not yours): 0 of 2 throws accepted; the YOUR SPOT tag shows while you're off your spot.
- Heartbeat 16.7 ms during the test (no frame cost seen; RenderStepped can't be measured while frozen).
- Output: no errors (only the old "CrateShop/EggPad not found" notes for the hidden stations).

## Not checked (needs a working 3D view or a second real player)
- How it looks: floor tones, gold arrows, rings, numbers' reading direction, MEGA LANE sign, pennants.
- Two real clients (Studio multi-client test can't be started from here). The fake thrower covers the client
  side; the server side keeps everything per player (own spot model, own ReadyAt, own bag/coins).
