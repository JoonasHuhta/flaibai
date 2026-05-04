extends Node
## AudioManager — centralised sound system for Flaibai.
## Place audio files in res://audio/sfx/ and res://audio/music/
## Files can be .ogg, .wav or .mp3
## If a file is missing the call silently does nothing — safe for placeholders.

# ---------------------------------------------------------------------------
# SOUND EFFECT DESCRIPTIONS (for asset hunting)
# ---------------------------------------------------------------------------
# bounce          → Short, punchy spring "boing". 80–120ms. Upward pitch.
#                   Think: a rubber ball hitting a hard floor, with spring.
#                   Reference: "boing.wav", "spring_jump.ogg"
#
# bounce_mushroom → Bigger, happier boing. 150ms. Higher pitch, slight reverb.
#                   Think: jumping on a trampoline / Mario's mushroom.
#
# bounce_bad      → Dull, flat thud. 100ms. Low pitch, no spring quality.
#                   Think: landing face-first on dirt. "thud.wav"
#
# bounce_ice      → Slippery whoosh + light clink. 120ms. Icy, cool.
#                   Think: skate blade on ice. "ice_slide.ogg"
#
# moss_stop       → Soft muffled thump. 80ms. Dead sound, no resonance.
#                   Think: landing on a thick carpet. "soft_thud.wav"
#
# launch          → Light "whoop" or swoosh upward. 100ms.
#                   Think: rocket ignition mini / cork pop. "launch.ogg"
#
# flip            → Short air-whoosh, 1 per full rotation. 80ms.
#                   Think: wind rush past ears. "whoosh_short.ogg"
#
# crash           → Smack + short crumple. 200ms. Impact, then settling.
#                   Think: HCR engine stall + body impact. "crash_impact.ogg"
#
# clean_streak    → Small positive chime / ding. 120ms. Musical, ascending.
#                   Think: coin collect sound. "ding.ogg", "chime.wav"
#
# flow_milestone  → Warm ascending 3-note tone. 300ms. Every 25% flow.
#                   Think: levelup sound light version. "power_up_short.ogg"
#
# level_complete  → Short fanfare. 1–2 seconds. Triumphant, fun.
#                   Think: Mario star collect + short chord. "fanfare.ogg"
#
# ui_tap          → Soft, neutral UI click. 30ms. Barely noticeable.
#                   Think: light keyboard tap. "ui_click.wav"
# ---------------------------------------------------------------------------

const SFX_DIR    := "res://audio/sfx/"
const MUSIC_DIR  := "res://audio/music/"

var _sfx_players: Dictionary = {}   # sfx_name → AudioStreamPlayer
var _music_player: AudioStreamPlayer = null
var _sfx_cache: Dictionary = {}     # path → AudioStream (or null)

# Volume settings (dB)
var sfx_volume_db  := 0.0
var music_volume_db := -6.0

func _ready() -> void:
	# Music player (looping, lower volume)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = music_volume_db
	add_child(_music_player)

func play_sfx(name: String, pitch_scale: float = 1.0) -> void:
	var stream := _load_sfx(name)
	if stream == null:
		return  # placeholder — no file yet, silent
	var player := _get_or_create_sfx_player(name)
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = sfx_volume_db
	player.play()

func play_music(filename: String, loop: bool = true) -> void:
	var path := MUSIC_DIR + filename
	if not ResourceLoader.exists(path):
		return  # no music file yet — silent
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_music_player.stream = stream
	# Enable looping if supported
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	_music_player.volume_db = music_volume_db
	_music_player.play()

func stop_music() -> void:
	if _music_player.playing:
		_music_player.stop()

func set_music_volume(db: float) -> void:
	music_volume_db = db
	_music_player.volume_db = db

func set_sfx_volume(db: float) -> void:
	sfx_volume_db = db

# --- Internal helpers ---

func _load_sfx(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	# Try common extensions in order
	for ext in ["ogg", "wav", "mp3"]:
		var path := SFX_DIR + name + "." + ext
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			_sfx_cache[name] = s
			return s
	# File not found — cache null so we don't re-scan every frame
	_sfx_cache[name] = null
	return null

func _get_or_create_sfx_player(name: String) -> AudioStreamPlayer:
	if _sfx_players.has(name):
		return _sfx_players[name]
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	add_child(p)
	_sfx_players[name] = p
	return p
