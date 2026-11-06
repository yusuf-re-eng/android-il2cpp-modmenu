package com.valvehack.modmenu;
import android.content.Context;
import android.content.SharedPreferences;
public final class Prefs {
    private static SharedPreferences cached;
    private Prefs() {}
    private static SharedPreferences sp(Context c) {
        SharedPreferences s = cached;
        if (s == null) {
            synchronized (Prefs.class) {
                s = cached;
                if (s == null) {
                    s = c.getApplicationContext().getSharedPreferences("valvehack", Context.MODE_PRIVATE);
                    cached = s;
                }
            }
        }
        return s;
    }
    public static boolean haptics(Context c) { return sp(c).getBoolean("haptics", true); }
    public static void setHaptics(Context c, boolean v) { sp(c).edit().putBoolean("haptics", v).apply(); }
    public static boolean noclipWanted(Context c) { return sp(c).getBoolean("noclipWanted", false); }
    public static void setNoclipWanted(Context c, boolean v) { sp(c).edit().putBoolean("noclipWanted", v).apply(); }
    public static boolean patchOn(Context c, String id) { return sp(c).getBoolean("p_" + id, false); }
    public static void setPatchOn(Context c, String id, boolean v) { sp(c).edit().putBoolean("p_" + id, v).apply(); }
    public static final String DEFAULT_CHAT =
        "t . m e / v a l v e h a c k\n" +
        "\u043d\u0430 \u0441\u0430\u043c\u043e\u043c \u0434\u0435\u043b\u0435 \u044f \u2014 \u0436\u0438\u0432\u043e\u0439 \u043c\u0435\u0440\u0442\u0432\u0435\u0446\n" +
        "Anlayamazsin...";
    public static String chatMessages(Context c) { return sp(c).getString("chatMessages", DEFAULT_CHAT); }
    public static void setChatMessages(Context c, String v) { sp(c).edit().putString("chatMessages", v).apply(); }
    public static int chatInterval(Context c) { return sp(c).getInt("chatInterval", 2); }
    public static void setChatInterval(Context c, int v) { sp(c).edit().putInt("chatInterval", Math.max(1, Math.min(60, v))).apply(); }
    public static boolean chatWanted(Context c) { return sp(c).getBoolean("chatWanted", false); }
    public static void setChatWanted(Context c, boolean v) { sp(c).edit().putBoolean("chatWanted", v).apply(); }
}
