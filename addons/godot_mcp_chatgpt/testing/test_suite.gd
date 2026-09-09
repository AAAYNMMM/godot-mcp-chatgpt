@tool
extends RefCounted

var _failures: Array[String] = []

func _mcp_reset_assertions() -> void:
    _failures.clear()

func get_failures() -> Array[String]:
    return _failures.duplicate()

func fail(message: String = "Test failed") -> void:
    _failures.append(message)

func assert_true(value: bool, message: String = "Expected true") -> void:
    if not value:
        fail(message)

func assert_false(value: bool, message: String = "Expected false") -> void:
    if value:
        fail(message)

func assert_eq(actual, expected, message: String = "") -> void:
    if actual != expected:
        fail(message if not message.is_empty() else "Expected %s, got %s" % [str(expected), str(actual)])

func assert_ne(actual, expected, message: String = "") -> void:
    if actual == expected:
        fail(message if not message.is_empty() else "Expected values to differ: %s" % str(actual))

func assert_not_null(value, message: String = "Expected non-null value") -> void:
    if value == null:
        fail(message)

func assert_null(value, message: String = "Expected null value") -> void:
    if value != null:
        fail(message)

func assert_approx(actual: float, expected: float, epsilon: float = 0.00001, message: String = "") -> void:
    if absf(actual - expected) > epsilon:
        fail(message if not message.is_empty() else "Expected %s ± %s, got %s" % [expected, epsilon, actual])