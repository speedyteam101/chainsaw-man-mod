package com.inkframe.brush

/** The stamp a brush repeats along a stroke. */
enum class DabShape {
    /** Anti-aliased hard circle (or ellipse when roundness < 1). */
    HARD,
    /** Round with a soft falloff: airbrushes. */
    SOFT,
    /** Speckled grain: pencils. */
    PENCIL,
    /** Coarse broken texture: chalk and charcoal. */
    CHALK,
    /** Hard edge with a little noise: dry ink. */
    INK,
}

/**
 * Everything that defines how a brush behaves. Values are the user-tunable
 * "Brush Studio" settings; all fractions are 0..1.
 */
data class BrushSpec(
    val id: String,
    val name: String,
    val shape: DabShape,
    /** Distance between stamps, as a fraction of the stamp diameter. */
    val spacing: Float = 0.08f,
    /** How much pen pressure shrinks the stamp (0 = constant size). */
    val pressureSize: Float = 0.6f,
    /** How much pen pressure fades the stamp. */
    val pressureOpacity: Float = 0f,
    /** Opacity of each stamp. Low flow builds up within a stroke. */
    val flow: Float = 1f,
    /** StreamLine: how strongly the stroke lags behind the pen to smooth it. */
    val streamline: Float = 0.3f,
    /** Length of the thin start of a stroke, relative to the brush size. */
    val taperStart: Float = 0f,
    val taperEnd: Float = 0f,
    val rotationJitter: Float = 0f,
    val followDirection: Boolean = false,
    /** 1 = circle, smaller = flatter ellipse (calligraphy). */
    val roundness: Float = 1f,
    /** Angle of a flat stamp in degrees when it does not follow the stroke. */
    val angle: Float = 0f,
    /** Random offset of each stamp, as a fraction of the size. */
    val scatter: Float = 0f,
    val sizeJitter: Float = 0f,
    val opacityJitter: Float = 0f,
    val defaultSize: Float = 12f,
    val defaultOpacity: Float = 1f,
    val maxSize: Float = 400f,
) {
    /** Only the user-tunable settings, used to store the user's changes. */
    fun tunables(): FloatArray = floatArrayOf(
        spacing, pressureSize, pressureOpacity, flow, streamline, taperStart, taperEnd, rotationJitter, scatter,
    )

    fun withTunables(v: FloatArray): BrushSpec = if (v.size < 9) this else copy(
        spacing = v[0].coerceIn(0.01f, 1.5f),
        pressureSize = v[1].coerceIn(0f, 1f),
        pressureOpacity = v[2].coerceIn(0f, 1f),
        flow = v[3].coerceIn(0.02f, 1f),
        streamline = v[4].coerceIn(0f, 1f),
        taperStart = v[5].coerceIn(0f, 1f),
        taperEnd = v[6].coerceIn(0f, 1f),
        rotationJitter = v[7].coerceIn(0f, 1f),
        scatter = v[8].coerceIn(0f, 2f),
    )
}

object Brushes {
    val all: List<BrushSpec> = listOf(
        BrushSpec(
            id = "studio_pen", name = "Studio Pen", shape = DabShape.HARD,
            spacing = 0.05f, pressureSize = 0.85f, streamline = 0.35f, taperStart = 0.5f, taperEnd = 0.6f,
            defaultSize = 8f,
        ),
        BrushSpec(
            id = "technical_pen", name = "Technical Pen", shape = DabShape.HARD,
            spacing = 0.05f, pressureSize = 0.15f, streamline = 0.45f, defaultSize = 5f,
        ),
        BrushSpec(
            id = "monoline", name = "Monoline", shape = DabShape.HARD,
            spacing = 0.05f, pressureSize = 0f, streamline = 0.25f, defaultSize = 6f,
        ),
        BrushSpec(
            id = "dry_ink", name = "Dry Ink", shape = DabShape.INK,
            spacing = 0.06f, pressureSize = 0.7f, streamline = 0.25f, taperStart = 0.3f, taperEnd = 0.3f,
            rotationJitter = 1f, defaultSize = 10f,
        ),
        BrushSpec(
            id = "pencil", name = "6B Pencil", shape = DabShape.PENCIL,
            spacing = 0.12f, pressureSize = 0.35f, pressureOpacity = 0.7f, flow = 0.75f, streamline = 0.15f,
            rotationJitter = 1f, defaultSize = 7f,
        ),
        BrushSpec(
            id = "sketch", name = "Sketch", shape = DabShape.PENCIL,
            spacing = 0.15f, pressureSize = 0.2f, pressureOpacity = 0.8f, flow = 0.45f, streamline = 0.05f,
            rotationJitter = 1f, defaultSize = 4f, defaultOpacity = 0.85f,
        ),
        BrushSpec(
            id = "marker", name = "Marker", shape = DabShape.HARD,
            spacing = 0.04f, pressureSize = 0.25f, streamline = 0.2f, defaultSize = 24f, defaultOpacity = 0.6f,
        ),
        BrushSpec(
            id = "calligraphy", name = "Calligraphy", shape = DabShape.HARD,
            spacing = 0.03f, pressureSize = 0.4f, streamline = 0.3f, roundness = 0.25f, angle = 45f,
            defaultSize = 18f,
        ),
        BrushSpec(
            id = "soft_airbrush", name = "Soft Airbrush", shape = DabShape.SOFT,
            spacing = 0.1f, pressureSize = 0.1f, pressureOpacity = 0.8f, flow = 0.12f, streamline = 0.1f,
            defaultSize = 120f, maxSize = 800f,
        ),
        BrushSpec(
            id = "medium_airbrush", name = "Medium Airbrush", shape = DabShape.SOFT,
            spacing = 0.08f, pressureSize = 0.3f, pressureOpacity = 0.5f, flow = 0.35f, streamline = 0.1f,
            defaultSize = 40f, maxSize = 600f,
        ),
        BrushSpec(
            id = "chalk", name = "Chalk", shape = DabShape.CHALK,
            spacing = 0.15f, pressureSize = 0.3f, pressureOpacity = 0.5f, flow = 0.8f, streamline = 0.1f,
            rotationJitter = 1f, scatter = 0.05f, defaultSize = 30f,
        ),
        BrushSpec(
            id = "charcoal", name = "Charcoal", shape = DabShape.CHALK,
            spacing = 0.1f, pressureSize = 0.5f, pressureOpacity = 0.6f, flow = 0.6f, streamline = 0.1f,
            rotationJitter = 1f, sizeJitter = 0.2f, scatter = 0.1f, defaultSize = 16f,
        ),
    )

    val default: BrushSpec get() = all[0]
    val defaultEraser: BrushSpec get() = all.first { it.id == "medium_airbrush" }

    fun byId(id: String?): BrushSpec? = all.firstOrNull { it.id == id }
}
