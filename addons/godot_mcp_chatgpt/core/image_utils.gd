@tool
extends RefCounted

const DEFAULT_MAX_RESOLUTION := 1280
const HARD_MAX_RESOLUTION := 2048
const MAX_PNG_BYTES := 5 * 1024 * 1024

static func encode_png(image: Image, requested_max_resolution: int = DEFAULT_MAX_RESOLUTION) -> Dictionary:
    if image == null or image.is_empty():
        return {"ok": false, "error": {"code": "IMAGE_EMPTY", "message": "Captured image is empty"}}
    var original_width := image.get_width()
    var original_height := image.get_height()
    var max_resolution := clampi(requested_max_resolution if requested_max_resolution > 0 else DEFAULT_MAX_RESOLUTION, 64, HARD_MAX_RESOLUTION)
    var copy := image.duplicate()
    _fit_longest_edge(copy, max_resolution)
    var png: PackedByteArray = copy.save_png_to_buffer()
    while png.size() > MAX_PNG_BYTES and maxi(copy.get_width(), copy.get_height()) > 256:
        copy.resize(maxi(1, int(copy.get_width() * 0.8)), maxi(1, int(copy.get_height() * 0.8)), Image.INTERPOLATE_LANCZOS)
        png = copy.save_png_to_buffer()
    if png.size() > MAX_PNG_BYTES:
        return {"ok": false, "error": {"code": "IMAGE_TOO_LARGE", "message": "PNG exceeds bounded response size", "bytes": png.size(), "limit": MAX_PNG_BYTES}}
    return {
        "ok": true,
        "data": Marshalls.raw_to_base64(png),
        "mime_type": "image/png",
        "width": copy.get_width(),
        "height": copy.get_height(),
        "original_width": original_width,
        "original_height": original_height,
        "bytes": png.size(),
    }

static func _fit_longest_edge(image: Image, max_resolution: int) -> void:
    var longest := maxi(image.get_width(), image.get_height())
    if longest <= max_resolution:
        return
    var scale := float(max_resolution) / float(longest)
    image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)