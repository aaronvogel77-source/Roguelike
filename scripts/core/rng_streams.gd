class_name RngStreams
extends RefCounted
## One master seed, many independent random streams.
## Each stream is derived from the master seed and its name, so adding
## random calls to one system never shifts the results of another.

var master_seed: int
var _streams: Dictionary = {}


func _init(seed_value: int) -> void:
	master_seed = seed_value


## Returns the generator for a named stream (e.g. "shop", "enemy_gen").
func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		rng.seed = ("%d:%s" % [master_seed, stream_name]).hash()
		_streams[stream_name] = rng
	return _streams[stream_name]
