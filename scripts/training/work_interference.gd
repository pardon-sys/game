class_name WorkInterference
extends RefCounted
## 连续劳动小游戏的时钟，不持有演员、来源、台词或存档。
## 只在可操作时调用advance；每6秒加强，提前0.6秒预告；特效0.65秒、反应3秒一次。
## 单次最多推进0.25秒，卡帧不补发一串命中；普通工作节点切换不得重建时钟。

const INTERVAL := 6.0
const WARNING := 0.6
const FX_INTERVAL := 0.65
const REACTION_INTERVAL := 3.0
const MAX_DELTA := 0.25
var elapsed := 0.0
var strong_count := 0
var _strong_left := INTERVAL
var _fx_left := 0.0
var _reaction_left := 1.5

func warning() -> bool:
	return _strong_left <= WARNING

func advance(delta: float) -> Dictionary:
	var dt := clampf(delta, 0.0, MAX_DELTA)
	elapsed += dt
	_strong_left -= dt
	_fx_left -= dt
	_reaction_left -= dt
	var out := {"dt": dt, "strong": false, "fx": false, "reaction": false}
	if _strong_left <= 0.00001:
		_strong_left = INTERVAL
		strong_count += 1
		out["strong"] = true
	if _fx_left <= 0.00001:
		_fx_left = FX_INTERVAL
		out["fx"] = true
	if _reaction_left <= 0.00001:
		_reaction_left = REACTION_INTERVAL
		out["reaction"] = true
	return out
