package com.silkie.launcher.settings

import android.content.SharedPreferences
import com.silkie.launcher.data.SortOrder
import com.silkie.launcher.mascot.Chattiness
import com.silkie.launcher.mascot.MascotStage
import org.json.JSONObject
import kotlin.properties.ReadWriteProperty
import kotlin.reflect.KProperty

enum class LayoutMode(val title: String) { GRID("Grid"), LIST("List"), CAROUSEL("Carousel") }

enum class IconShape(val title: String) {
    ORIGINAL("Original"),
    CIRCLE("Circle"),
    SQUIRCLE("Squircle"),
    ROUNDED("Rounded square"),
    SQUARE("Square"),
    TEARDROP("Teardrop"),
    HEXAGON("Hexagon"),
    OCTAGON("Octagon"),
    CLOVER("Clover"),
    DIAMOND("Diamond"),
}

enum class BackgroundStyle(val title: String) {
    SOLID("Solid color"),
    GRADIENT("Gradient"),
    RADIAL("Glow"),
    DOTS("Dots"),
    GRID("Grid"),
    HORIZON("Retro horizon"),
    IMAGE("Picture"),
    WALLPAPER("System wallpaper"),
}

enum class Ambient(val title: String) {
    NONE("None"),
    SILK("Drifting silk"),
    FIREFLIES("Fireflies"),
    SNOW("Snow"),
    BUBBLES("Bubbles"),
    SPARKLES("Sparkles"),
    PETALS("Petals"),
}

enum class CardStyle(val title: String) { FLAT("Flat"), OUTLINED("Outlined"), GLASS("Glass"), RAISED("Raised") }

enum class FontChoice(val title: String, val family: String) {
    DEFAULT("Default", "sans-serif"),
    MEDIUM("Medium", "sans-serif-medium"),
    LIGHT("Light", "sans-serif-light"),
    CONDENSED("Condensed", "sans-serif-condensed"),
    SERIF("Serif", "serif"),
    MONO("Monospace", "monospace"),
    CASUAL("Casual", "casual"),
    CURSIVE("Cursive", "cursive"),
    SMALLCAPS("Small caps", "sans-serif-smallcaps"),
}

enum class ClockStyle(val title: String) { LARGE("Large, on the home tab"), COMPACT("Small, in the top bar"), HIDDEN("Hidden") }

enum class Tab(val title: String) { HOME("Home"), GAMES("Games"), APPS("Apps"), FAVORITES("Favorites") }

enum class GestureAction(val title: String) {
    NONE("Do nothing"),
    SEARCH("Search"),
    APPS("Open all apps"),
    GAMES("Open games"),
    FAVORITES("Open favorites"),
    SETTINGS("Silkie settings"),
    MASCOT("Talk to the mascot"),
    LAYOUT("Switch grid / list / carousel"),
}

enum class MascotPosition(val title: String) { LEFT("Left"), RIGHT("Right"), HIDDEN("Hidden") }

enum class MascotHat(val title: String) {
    NONE("None"),
    BEANIE("Beanie"),
    CROWN("Crown"),
    WIZARD("Wizard hat"),
    PARTY("Party hat"),
    HEADPHONES("Headphones"),
    BOW("Bow"),
    FLOWER("Flower"),
    CAP("Cap"),
    HORNS("Little horns"),
    HALO("Halo"),
}

enum class MascotEyes(val title: String) {
    ROUND("Round"),
    SPARKLE("Sparkly"),
    ANIME("Big and shiny"),
    DOT("Dots"),
    HAPPY("Always smiling"),
    SLEEPY("Sleepy"),
}

enum class MascotAccessory(val title: String) {
    NONE("None"),
    SCARF("Scarf"),
    GLASSES("Glasses"),
    SUNGLASSES("Sunglasses"),
    BOWTIE("Bow tie"),
    CONTROLLER("Game controller"),
}

/**
 * Every customization option, stored in SharedPreferences. Each setter bumps [revision] so open
 * screens can tell they need to restyle.
 */
class Prefs(private val sp: SharedPreferences) {
    var revision = 0
        private set

    // Theme
    var themeName by string("theme_name", "Moonlight")
    var bgColor by int("bg_color", 0xFF14121B.toInt())
    var bgColor2 by int("bg_color2", 0xFF2B2140.toInt())
    var cardColor by int("card_color", 0xFF241F31.toInt())
    var textColor by int("text_color", 0xFFF3EEF8.toInt())
    var accentColor by int("accent_color", 0xFFFFB86B.toInt())
    var cardStyle by enum("card_style", CardStyle.GLASS, CardStyle.entries)
    var cornerRadius by int("corner_radius", 18)
    var font by enum("font", FontChoice.DEFAULT, FontChoice.entries)
    var fontScale by int("font_scale", 100)

    // Background
    var bgStyle by enum("bg_style", BackgroundStyle.GRADIENT, BackgroundStyle.entries)
    var gradientAngle by int("gradient_angle", 135)
    var bgImage by string("bg_image", "")
    var bgDim by int("bg_dim", 25)
    var bgBlur by int("bg_blur", 0)
    var ambient by enum("ambient", Ambient.SILK, Ambient.entries)
    var ambientDensity by int("ambient_density", 40)

    // Library layout
    var layoutMode by enum("layout_mode", LayoutMode.GRID, LayoutMode.entries)
    var gridColumns by int("grid_columns", 0) // 0 = automatic
    var iconSize by int("icon_size", 64)
    var showLabels by bool("show_labels", true)
    var labelSize by int("label_size", 12)
    var twoLineLabels by bool("two_line_labels", false)
    var tileSpacing by int("tile_spacing", 10)
    var focusScale by int("focus_scale", 112)
    var showPlaytimeOnTiles by bool("show_playtime_tiles", false)
    var sortOrder by enum("sort_order", SortOrder.NAME, SortOrder.entries)
    var startTab by enum("start_tab", Tab.HOME, Tab.entries)
    var showGamesTab by bool("tab_games", true)
    var showAppsTab by bool("tab_apps", true)
    var showFavoritesTab by bool("tab_favorites", true)
    var showCollectionTabs by bool("tab_collections", true)

    // Icons
    var iconShape by enum("icon_shape", IconShape.SQUIRCLE, IconShape.entries)
    var themedIcons by bool("themed_icons", false)
    var legacyIconPlate by bool("legacy_plate", true)
    var iconOutline by bool("icon_outline", false)
    var grayscaleIcons by bool("grayscale_icons", false)

    // Home tab
    var showHero by bool("show_hero", true)
    var showRecentShelf by bool("shelf_recent", true)
    var showFavoritesShelf by bool("shelf_favorites", true)
    var showGamesShelf by bool("shelf_games", true)
    var showAppsShelf by bool("shelf_apps", false)
    var shelfLength by int("shelf_length", 12)
    var showStats by bool("show_stats", true)
    var showWidgets by bool("show_widgets", true)

    // Clock and status
    var clockStyle by enum("clock_style", ClockStyle.LARGE, ClockStyle.entries)
    var clock24h by bool("clock_24h", false)
    var clockSeconds by bool("clock_seconds", false)
    var showDate by bool("show_date", true)
    var showBattery by bool("show_battery", true)
    var hideStatusBar by bool("hide_status_bar", false)
    var showHints by bool("show_hints", true)

    // Mascot
    var mascotPosition by enum("mascot_position", MascotPosition.LEFT, MascotPosition.entries)
    var mascotName by string("mascot_name", "Silkie")
    var mascotStage by enum("mascot_stage", MascotStage.AUTO, MascotStage.entries)
    var mascotBody by int("mascot_body", 0xFFFFF4E6.toInt())
    var mascotWings by int("mascot_wings", 0xFFFFD9A8.toInt())
    var mascotCheeks by int("mascot_cheeks", 0xFFFF9EB5.toInt())
    var mascotEyes by enum("mascot_eyes", MascotEyes.ROUND, MascotEyes.entries)
    var mascotHat by enum("mascot_hat", MascotHat.NONE, MascotHat.entries)
    var mascotAccessory by enum("mascot_accessory", MascotAccessory.NONE, MascotAccessory.entries)
    var mascotSize by int("mascot_size", 100)
    var mascotChattiness by enum("mascot_chattiness", Chattiness.NORMAL, Chattiness.entries)
    var mascotBubbles by bool("mascot_bubbles", true)
    var mascotReacts by bool("mascot_reacts", true)
    var mascotSleeps by bool("mascot_sleeps", true)
    var mascotBuddy by bool("mascot_buddy", true)
    var lastStage by string("mascot_last_stage", "")

    // Motion, sound and controls
    var reduceMotion by bool("reduce_motion", false)
    var animationSpeed by int("animation_speed", 100)
    var haptics by bool("haptics", true)
    var sounds by bool("sounds", false)
    var swapAB by bool("swap_ab", false)
    var typeToSearch by bool("type_to_search", true)

    // Gestures
    var swipeUp by enum("gesture_up", GestureAction.APPS, GestureAction.entries)
    var swipeDown by enum("gesture_down", GestureAction.SEARCH, GestureAction.entries)
    var doubleTap by enum("gesture_double_tap", GestureAction.MASCOT, GestureAction.entries)
    var longPress by enum("gesture_long_press", GestureAction.SETTINGS, GestureAction.entries)
    var swipeTabs by bool("swipe_tabs", true)

    // Widgets: JSON array of {"id": appWidgetId, "h": heightDp}
    var widgets by string("widgets", "[]")

    /** Scales a duration by the animation speed setting; 0 when motion is reduced. */
    fun duration(ms: Long): Long = if (reduceMotion) 0 else ms * 100 / animationSpeed.coerceAtLeast(10)

    fun toJson(): JSONObject {
        val out = JSONObject()
        for ((k, v) in sp.all) {
            when (v) {
                is Boolean -> out.put(k, JSONObject().put("b", v))
                is Int -> out.put(k, JSONObject().put("i", v))
                is String -> out.put(k, JSONObject().put("s", v))
            }
        }
        return out
    }

    fun loadJson(json: JSONObject) {
        val e = sp.edit().clear()
        for (k in json.keys()) {
            val v = json.optJSONObject(k) ?: continue
            when {
                v.has("b") -> e.putBoolean(k, v.getBoolean("b"))
                v.has("i") -> e.putInt(k, v.getInt("i"))
                v.has("s") -> e.putString(k, v.getString("s"))
            }
        }
        e.apply()
        revision++
    }

    fun reset() {
        val keepWidgets = widgets
        sp.edit().clear().apply()
        widgets = keepWidgets
    }

    /** Groups several changes (a theme preset) into one revision bump. */
    fun edit(block: Prefs.() -> Unit) {
        block()
        revision++
    }

    private fun bool(key: String, def: Boolean) = object : ReadWriteProperty<Prefs, Boolean> {
        override fun getValue(thisRef: Prefs, property: KProperty<*>) = sp.getBoolean(key, def)
        override fun setValue(thisRef: Prefs, property: KProperty<*>, value: Boolean) {
            sp.edit().putBoolean(key, value).apply()
            revision++
        }
    }

    private fun int(key: String, def: Int) = object : ReadWriteProperty<Prefs, Int> {
        override fun getValue(thisRef: Prefs, property: KProperty<*>) = sp.getInt(key, def)
        override fun setValue(thisRef: Prefs, property: KProperty<*>, value: Int) {
            sp.edit().putInt(key, value).apply()
            revision++
        }
    }

    private fun string(key: String, def: String) = object : ReadWriteProperty<Prefs, String> {
        override fun getValue(thisRef: Prefs, property: KProperty<*>) = sp.getString(key, def) ?: def
        override fun setValue(thisRef: Prefs, property: KProperty<*>, value: String) {
            sp.edit().putString(key, value).apply()
            revision++
        }
    }

    private fun <E : Enum<E>> enum(key: String, def: E, values: List<E>) = object : ReadWriteProperty<Prefs, E> {
        override fun getValue(thisRef: Prefs, property: KProperty<*>): E {
            val name = sp.getString(key, null) ?: return def
            return values.firstOrNull { it.name == name } ?: def
        }

        override fun setValue(thisRef: Prefs, property: KProperty<*>, value: E) {
            sp.edit().putString(key, value.name).apply()
            revision++
        }
    }
}
