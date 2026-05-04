# Flaibai — Audio Assets

## SFX (audio/sfx/)
Etsi .ogg tai .wav tiedostot, nimeä alla olevien mukaan:

| Tiedosto          | Kuvaus                                                               | Kesto  |
|-------------------|----------------------------------------------------------------------|--------|
| bounce.ogg        | Springing boing sound — rubber ball + spring. Punchy, upward pitch  | 80ms   |
| bounce_mushroom.ogg | Bigger bouncier boing. Higher pitch, slight reverb, trampoline vibe | 150ms  |
| bounce_bad.ogg    | Dull flat thud. Low pitch, no spring. Landing wrong                 | 100ms  |
| bounce_ice.ogg    | Slippery whoosh + light clink. Icy, sliding sound                   | 120ms  |
| moss_stop.ogg     | Soft muffled thump. Dead sound, carpet-like. No resonance           | 80ms   |
| launch.ogg        | Light upward swoosh or cork pop. First tap to start                 | 100ms  |
| flip.ogg          | Short air-whoosh. One per full rotation in the air                  | 80ms   |
| crash.ogg         | Impact smack + short crumple. HCR-style hit                         | 200ms  |
| clean_streak.ogg  | Small positive chime/ding. Musical, ascending. Coin collect style   | 120ms  |
| flow_milestone.ogg| Warm ascending 3-note tone. Every 25% flow milestone                | 300ms  |
| level_complete.ogg| Short fanfare 1-2s. Triumphant, fun. Checkered flag moment         | 1-2s   |
| ui_tap.ogg        | Soft neutral UI click. Barely noticeable                            | 30ms   |

## Music (audio/music/)
| Tiedosto          | Kuvaus                                                               |
|-------------------|----------------------------------------------------------------------|
| title_theme.ogg   | Calm, atmospheric title screen music. Looping. Upbeat but relaxed  |
| game_theme.ogg    | Upbeat arcade background music. Looping. Energetic but not frantic  |

## Hyviä lähteitä:
- https://freesound.org  (tag: boing, spring, bounce, whoosh)
- https://opengameart.org (section: sound effects)
- https://itch.io/game-assets/free/tag-sound-effects

## Lisäys Godotiin:
1. Kopioi .ogg tiedostot audio/sfx/ tai audio/music/ kansioon
2. Godot löytää ne automaattisesti — uudelleenkäynnistys saattaa tarvitaan
3. AudioManager lataa ne automaattisesti nimellä (ilman tiedostopäätettä)
