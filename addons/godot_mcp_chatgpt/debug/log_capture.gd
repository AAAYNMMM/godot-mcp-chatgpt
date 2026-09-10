@tool
extends Logger

const MAX_ENTRIES := 1000

var _entries: Array = []
var _sequence := 0
var _dropped := 0
var _mutex := Mutex.new()

func _log_message(message: String, error: bool) -> void:
    _append("error" if error else "info", message)

func _log_error(
    function: String,
    file: String,
    line: int,
    code: String,
    rationale: String,
    _editor_notify: bool,
    error_type: int,
    _script_backtraces: Array,
) -> void:
    var level := "warning" if error_type == 1 else "error"
    var text := rationale if not rationale.is_empty() else code
    if text.is_empty():
        text = "Godot error"
    _append(level, text, file, line, function, {"code": code, "error_type": error_type})

func _append(level: String, text: String, path: String = "", line: int = 0, function: String = "", details: Dictionary = {}) -> void:
    _mutex.lock()
    _sequence += 1
    _entries.append({
        "cursor": _sequence,
        "timestamp_ms": Time.get_ticks_msec(),
        "level": level,
        "text": _sanitize_text(text),
        "path": path,
        "line": line,
        "function": function,
        "details": details.duplicate(true),
    })
    if _entries.size() > MAX_ENTRIES:
        var remove_count := _entries.size() - MAX_ENTRIES
        _entries = _entries.slice(remove_count)
        _dropped += remove_count
    _mutex.unlock()

func _sanitize_text(value: String) -> String:
    var out := ""
    var i := 0
    while i < value.length():
        var code := value.unicode_at(i)
        if code == 27:
            i += 1
            if i < value.length() and value.unicode_at(i) == 91:
                i += 1
                while i < value.length():
                    var c := value.unicode_at(i)
                    i += 1
                    if c >= 64 and c <= 126:
                        break
            continue
        if code < 32 and code not in [9, 10, 13]:
            i += 1
            continue
        out += value.substr(i, 1)
        i += 1
    return out

func read_since(cursor: int = 0, limit: int = 200, level: String = "") -> Dictionary:
    _mutex.lock()
    var copied := _entries.duplicate(true)
    var current := _sequence
    var dropped := _dropped
    _mutex.unlock()
    var out: Array = []
    var requested := clampi(limit, 1, 500)
    for entry_value in copied:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        if int(entry.get("cursor", 0)) <= cursor:
            continue
        if not level.is_empty() and str(entry.get("level", "")) != level:
            continue
        out.append(entry)
        if out.size() >= requested:
            break
    var first_cursor := int(copied[0].get("cursor", 0)) if not copied.is_empty() and copied[0] is Dictionary else current + 1
    return {
        "entries": out,
        "cursor": current,
        "dropped": dropped,
        "truncated": cursor > 0 and cursor < first_cursor - 1,
        "available": copied.size(),
    }

func recent(limit: int = 100) -> Dictionary:
    return read_since(maxi(0, _sequence - clampi(limit, 1, 500)), limit)

func clear() -> Dictionary:
    _mutex.lock()
    var previous := _entries.size()
    _entries.clear()
    _dropped = 0
    var cursor := _sequence
    _mutex.unlock()
    return {"cleared": previous, "cursor": cursor}

func cursor() -> int:
    _mutex.lock()
    var value := _sequence
    _mutex.unlock()
    return value