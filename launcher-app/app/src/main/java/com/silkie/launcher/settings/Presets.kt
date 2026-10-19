package com.silkie.launcher.settings

/** A ready-made look. Applying one sets colors, background and ambience in one go. */
class ThemePreset(
    val name: String,
    val bg: Int,
    val bg2: Int,
    val card: Int,
    val text: Int,
    val accent: Int,
    val background: BackgroundStyle,
    val ambient: Ambient,
    val font: FontChoice = FontChoice.DEFAULT,
    val shape: IconShape? = null,
    val corner: Int? = null,
    val cardStyle: CardStyle? = null,
) {
    fun applyTo(p: Prefs) = p.edit {
        themeName = name
        bgColor = bg
        bgColor2 = bg2
        cardColor = card
        textColor = text
        accentColor = accent
        bgStyle = background
        ambient = this@ThemePreset.ambient
        font = this@ThemePreset.font
        shape?.let { iconShape = it }
        corner?.let { cornerRadius = it }
        this@ThemePreset.cardStyle?.let { cardStyle = it }
    }
}

object Presets {
    val all = listOf(
        ThemePreset("Moonlight", 0xFF14121B.toInt(), 0xFF2B2140.toInt(), 0xFF241F31.toInt(), 0xFFF3EEF8.toInt(), 0xFFFFB86B.toInt(), BackgroundStyle.GRADIENT, Ambient.SILK, shape = IconShape.SQUIRCLE, corner = 18, cardStyle = CardStyle.GLASS),
        ThemePreset("AMOLED", 0xFF000000.toInt(), 0xFF000000.toInt(), 0xFF101012.toInt(), 0xFFFFFFFF.toInt(), 0xFF5AC8FA.toInt(), BackgroundStyle.SOLID, Ambient.NONE, cardStyle = CardStyle.OUTLINED),
        ThemePreset("Retro Pocket", 0xFF0F380F.toInt(), 0xFF306230.toInt(), 0xFF306230.toInt(), 0xFFCADC9F.toInt(), 0xFF9BBC0F.toInt(), BackgroundStyle.GRID, Ambient.NONE, FontChoice.MONO, IconShape.SQUARE, 0, CardStyle.OUTLINED),
        ThemePreset("Sakura", 0xFFFFF0F5.toInt(), 0xFFFFD6E7.toInt(), 0xFFFFFFFF.toInt(), 0xFF4A2B3A.toInt(), 0xFFE85D9A.toInt(), BackgroundStyle.GRADIENT, Ambient.PETALS, shape = IconShape.CLOVER, corner = 24, cardStyle = CardStyle.RAISED),
        ThemePreset("Forest", 0xFF0E1F17.toInt(), 0xFF1F3B2C.toInt(), 0xFF1C3328.toInt(), 0xFFE6F2EA.toInt(), 0xFF7BD389.toInt(), BackgroundStyle.RADIAL, Ambient.FIREFLIES, shape = IconShape.TEARDROP),
        ThemePreset("Ocean", 0xFF06192E.toInt(), 0xFF0B3D63.toInt(), 0xFF0F2A44.toInt(), 0xFFE3F2FF.toInt(), 0xFF4FC3F7.toInt(), BackgroundStyle.GRADIENT, Ambient.BUBBLES, shape = IconShape.CIRCLE),
        ThemePreset("Paper", 0xFFF6F3EC.toInt(), 0xFFECE6D8.toInt(), 0xFFFFFFFF.toInt(), 0xFF2B2A28.toInt(), 0xFF3A6EA5.toInt(), BackgroundStyle.DOTS, Ambient.NONE, FontChoice.SERIF, IconShape.ROUNDED, 12, CardStyle.OUTLINED),
        ThemePreset("Synthwave", 0xFF1A0B2E.toInt(), 0xFF3D0E4F.toInt(), 0xFF2A1240.toInt(), 0xFFFDE7FF.toInt(), 0xFFFF3EA5.toInt(), BackgroundStyle.HORIZON, Ambient.SPARKLES, FontChoice.CONDENSED, IconShape.HEXAGON),
        ThemePreset("Chainsaw", 0xFF1A0D0A.toInt(), 0xFF3B120C.toInt(), 0xFF2B1410.toInt(), 0xFFFFEDE3.toInt(), 0xFFFF7A1A.toInt(), BackgroundStyle.RADIAL, Ambient.SPARKLES, FontChoice.CONDENSED, IconShape.OCTAGON, 6, CardStyle.RAISED),
        ThemePreset("Snowfall", 0xFF1B2433.toInt(), 0xFF3A4D6B.toInt(), 0xFF253247.toInt(), 0xFFF0F6FF.toInt(), 0xFFBFE3FF.toInt(), BackgroundStyle.GRADIENT, Ambient.SNOW, shape = IconShape.CIRCLE),
        ThemePreset("Sunset", 0xFF2D1B3D.toInt(), 0xFFE0705A.toInt(), 0xFF3A2547.toInt(), 0xFFFFF3E6.toInt(), 0xFFFFC857.toInt(), BackgroundStyle.GRADIENT, Ambient.FIREFLIES, FontChoice.MEDIUM),
        ThemePreset("Mint", 0xFFE9FBF4.toInt(), 0xFFC8F1E1.toInt(), 0xFFFFFFFF.toInt(), 0xFF1E3A32.toInt(), 0xFF14A37F.toInt(), BackgroundStyle.RADIAL, Ambient.BUBBLES, FontChoice.CASUAL, IconShape.SQUIRCLE),
    )
}
