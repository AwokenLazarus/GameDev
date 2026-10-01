class_name SmokeSeed
extends RefCounted
## Seeds the global RNG for one headless smoke scene.
## `-- seed=N` overrides the scene default. A per-peer RandomNumberGenerator
## is the networked co-op follow-up; this helper does not add one.


static func begin(default_seed: int) -> int:
	var n := default_seed
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			n = int(arg.substr(5))
	seed(n)
	print("SEED=%d" % n)
	return n


static func fail_line(marker: String, n: int, detail: String = "") -> String:
	if detail.is_empty():
		return "%s SEED=%d" % [marker, n]
	return "%s SEED=%d %s" % [marker, n, detail]
