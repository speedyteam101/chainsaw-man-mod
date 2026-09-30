package com.inkframe.model

enum class PlayMode(val label: String) {
    LOOP("Loop"),
    PING_PONG("Ping-Pong"),
    ONE_SHOT("One Shot"),
}

enum class LayerBlend(val label: String, val short: String) {
    NORMAL("Normal", "N"),
    MULTIPLY("Multiply", "M"),
    SCREEN("Screen", "S"),
    OVERLAY("Overlay", "O"),
    ADD("Add", "Ad"),
    DARKEN("Darken", "D"),
    LIGHTEN("Lighten", "L"),
    COLOR_BURN("Color Burn", "Cb"),
    COLOR_DODGE("Color Dodge", "Cd"),
    SOFT_LIGHT("Soft Light", "Sl"),
    HARD_LIGHT("Hard Light", "Hl"),
    DIFFERENCE("Difference", "Df"),
    HUE("Hue", "H"),
    COLOR("Color", "C"),
    LUMINOSITY("Luminosity", "Lu");

    companion object {
        fun of(name: String?): LayerBlend = entries.firstOrNull { it.name == name } ?: NORMAL
    }
}

/**
 * A layer spans the whole animation: every frame has one cell per layer.
 * The pixels of a cell live in the [CellStore] under [Project.cellKey].
 */
class Layer(val id: String, var name: String) {
    var visible = true
    var opacity = 1f
    var blend = LayerBlend.NORMAL
    var alphaLock = false

    fun copy(): Layer = Layer(id, name).also {
        it.visible = visible
        it.opacity = opacity
        it.blend = blend
        it.alphaLock = alphaLock
    }
}

/** A drawing in the timeline. [hold] is how many ticks (1/fps s) it stays on screen. */
class Frame(val id: String, var hold: Int = 1) {
    fun copy(): Frame = Frame(id, hold)
}

class OnionSettings {
    var enabled = true
    var before = 1
    var after = 1
    var opacity = 0.35f
    var colored = true
    /** When false, onion skins show only the active layer of the neighbouring frames. */
    var allLayers = false

    fun copyFrom(o: OnionSettings) {
        enabled = o.enabled
        before = o.before
        after = o.after
        opacity = o.opacity
        colored = o.colored
        allLayers = o.allLayers
    }
}

/** Immutable copy of the parts of a project that structural undo restores. */
class Structure(
    val layers: List<Layer>,
    val frames: List<Frame>,
    val currentFrame: Int,
    val activeLayer: Int,
)

class Project(val id: String, var name: String, val width: Int, val height: Int) {
    var fps = 12
    var backgroundColor = 0xFFFFFFFF.toInt()
    var backgroundVisible = true
    var playMode = PlayMode.LOOP
    val onion = OnionSettings()

    /** Bottom layer first. */
    val layers = ArrayList<Layer>()
    val frames = ArrayList<Frame>()

    var currentFrame = 0
    var activeLayer = 0

    var createdAt = System.currentTimeMillis()
    var modifiedAt = createdAt

    val totalTicks: Int get() = frames.sumOf { it.hold }

    fun snapshot() = Structure(
        layers.map { it.copy() },
        frames.map { it.copy() },
        currentFrame,
        activeLayer,
    )

    fun restore(s: Structure) {
        layers.clear()
        layers.addAll(s.layers.map { it.copy() })
        frames.clear()
        frames.addAll(s.frames.map { it.copy() })
        currentFrame = s.currentFrame.coerceIn(0, frames.size - 1)
        activeLayer = s.activeLayer.coerceIn(0, layers.size - 1)
    }

    fun frameIndex(id: String) = frames.indexOfFirst { it.id == id }
    fun layerIndex(id: String) = layers.indexOfFirst { it.id == id }

    companion object {
        const val MAX_SIDE = 4096

        fun cellKey(frameId: String, layerId: String) = "${frameId}_$layerId"
        fun frameIdOf(cellKey: String) = cellKey.substringBefore('_')
        fun layerIdOf(cellKey: String) = cellKey.substringAfter('_')
    }
}
