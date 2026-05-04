# Flaibai Level Contract

Each playable level scene must contain these nodes at the scene root:

- `GameManager`
- `RetryLayer`
- `GoalZone`
- `Flaibai`
- `Flaibai/Body`
- `Flaibai/LeftFoot`
- `Flaibai/RightFoot`
- `Flaibai/HeadContact`
- `Camera2D`
- `RetryLayer/ScoreboardUI`

`Flaibai` must be an instance of `res://scenes/player/player_rig.tscn`. Do not paste the player body, feet, head sensor, or visuals directly into a level scene.

All landable surfaces must be `StaticBody2D` nodes in the `ground` group.

Optional surface groups:

- `mushroom`
- `moss`
- `ice`

Goal rules:

- `GoalZone` should sit above a `FinalPlatform`.
- `GoalZone` polls body and foot positions, so it is more reliable than a pure `body_entered` trigger.
- The landing pad should include `ProgressFill` to show hold progress.

Timing rules:

- Level records are stored in `user://flaibai_records.cfg`.
- Each level keeps a local top 10 time list.
- Do not write saves under `res://`; Android builds cannot rely on writing there.

Before building, run:

```powershell
& 'C:\Users\jvker\AppData\Local\Temp\AweZip\Temp1\AweZip2\Godot_v4.6.2-stable_win64.exe' --headless --path . --script tools\check_level_players.gd
```

Next architecture step:

- Extract shared UI/camera/manager into a `Game.tscn`.
- Keep future level scenes as geometry only: surfaces, spawn point, goal zone, decoration.
