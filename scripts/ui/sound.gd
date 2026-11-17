class_name Sound
extends RefCounted
## Sound effects and music (all CC0, see docs/AUDIO_CREDITS.md).
## Static helpers: Sound.play("hit"), Sound.music("battle"). The players live on
## a small host node under the scene root, created on first use. Two buses
## ("Music", "SFX") carry the volumes the player sets in the menu; settings are
## kept in user://audio.cfg. Every button press clicks automatically.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const SETTINGS_PATH := "user://audio.cfg"
## Effect id -> files (one is picked at random, with a slight pitch change).
const SFX := {
	"click": ["click"], "back": ["back"], "error": ["error"], "confirm": ["confirm"],
	"card_place": ["card_place_1", "card_place_2", "card_place_3"], "card_slide": ["card_slide"],
	"card_flip": ["card_flip_1", "card_flip_2"], "pack_open": ["pack_open"], "shuffle": ["shuffle"],
	"coins": ["coins_1", "coins_2", "coins_3"], "sell": ["sell"],
	"hit": ["hit_1", "hit_2", "hit_3"], "punch": ["punch_1", "punch_2"], "hit_heavy": ["hit_heavy"],
	"shield": ["shield_1", "shield_2"], "burn": ["burn_1", "burn_2"], "bleed": ["bleed_1", "bleed_2"],
	"curse": ["curse"], "magic": ["magic"], "heal": ["heal"], "revive": ["revive"], "fusion": ["fusion"],
	"death_enemy": ["death_enemy"], "death_player": ["death_player"], "roar": ["roar"], "gem": ["gem"],
	"chest": ["chest"], "book": ["book"], "creak": ["creak"], "level_up": ["level_up"],
	"bell": ["bell_1", "bell_2", "bell_3"], "bell_big": ["bell_1"], "boom": ["boom"],
}
const MUSIC := ["menu", "planning", "vault", "battle", "boss"]
const SFX_PLAYERS := 10
const FADE := 0.8

static var music_volume := 0.7
static var sfx_volume := 0.8
static var muted := false
static var _host: Node
static var _sfx: Array = []
static var _next := 0
static var _music: Array = []  # two players for crossfades
static var _current_music := ""
static var _streams := {}
static var _pending_music := ""


## Call once from the first scene: buses, settings and the button click hook.
static func setup(tree: SceneTree) -> void:
	if _host != null and is_instance_valid(_host):
		return
	_load_settings()
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	_host = Node.new()
	_host.name = "SoundHost"
	_host.ready.connect(func() -> void:
		if _pending_music != "":
			music(_pending_music)
			_pending_music = "")
	_host.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_host)
	for i in SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		_host.add_child(player)
		_sfx.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = -80.0
		_host.add_child(player)
		_music.append(player)
	_apply_volumes()
	# Every button in the game clicks when pressed.
	tree.node_added.connect(func(node: Node) -> void:
		if node is BaseButton and not node.has_meta("silent"):
			(node as BaseButton).pressed.connect(func() -> void: play("click", -6.0)))


static func _ready_to_play() -> bool:
	return _host != null and is_instance_valid(_host) and _host.is_inside_tree()


static func play(id: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _ready_to_play() or muted or not SFX.has(id):
		return
	var files: Array = SFX[id]
	var stream := _stream(SFX_DIR + String(files[randi() % files.size()]) + ".ogg")
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx[_next]
	_next = (_next + 1) % _sfx.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	player.play()


## Switches the music with a short crossfade ("" stops it).
static func music(id: String) -> void:
	if _music.is_empty() or id == _current_music:
		return
	if not _ready_to_play():
		# The host joins the tree at the end of this frame: the wish waits until then.
		_pending_music = id
		return
	_current_music = id
	var old: AudioStreamPlayer = _music[0]
	var new: AudioStreamPlayer = _music[1]
	_music.reverse()
	if old.playing:
		var fade := _host.create_tween()
		fade.tween_property(old, "volume_db", -60.0, FADE)
		fade.tween_callback(old.stop)
	if id == "":
		return
	var stream := _stream(MUSIC_DIR + id + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	new.stream = stream
	new.volume_db = -60.0
	new.play()
	_host.create_tween().tween_property(new, "volume_db", 0.0, FADE)


static func set_volumes(music_value: float, sfx_value: float, mute: bool) -> void:
	music_volume = clampf(music_value, 0.0, 1.0)
	sfx_volume = clampf(sfx_value, 0.0, 1.0)
	muted = mute
	_apply_volumes()
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("audio", "muted", muted)
	config.save(SETTINGS_PATH)


static func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = float(config.get_value("audio", "music", music_volume))
		sfx_volume = float(config.get_value("audio", "sfx", sfx_volume))
		muted = bool(config.get_value("audio", "muted", muted))


static func _apply_volumes() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			continue
		AudioServer.set_bus_mute(index, muted or float(pair[1]) <= 0.001)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(float(pair[1]), 0.001)))


static func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]
