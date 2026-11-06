#!/data/data/com.termux/files/usr/bin/bash
PROJE="$HOME/valvehack"
PKG="com.valvehack.modmenu"
SURUM="5.0.0"
KOD=500
PLATFORM="android-34"
BT="34.0.0"
CMDTOOLS="11076708"
R8V="8.1.44"
R8URL="https://storage.googleapis.com/r8-releases/raw/${R8V}/r8lib.jar"
K=$'\033[0;31m'; Y=$'\033[0;32m'; C=$'\033[0;36m'; P=$'\033[0;35m'; R=$'\033[0m'
yaz() { printf "\n%s[%s]%s %s\n" "$C" "$(date +%H:%M:%S)" "$R" "$1"; }
ok() { printf "  %s✓%s %s\n" "$Y" "$R" "$1"; }
hata() { printf "  %s✗%s %s\n" "$K" "$R" "$1" >&2; exit 1; }

yaz "Environment"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$TERMUX_PREFIX/bin:$TERMUX_PREFIX/bin/applets:/system/bin:/system/xbin:$PATH"
[ "$(uname -m)" = "aarch64" ] || hata "aarch64 required"
for p in openjdk-17 aapt2 clang wget unzip zip; do
  dpkg -s "$p" >/dev/null 2>&1 || yes 2>/dev/null | pkg install -y "$p" >/dev/null 2>&1 || true
done
JAVA=$(command -v java); JAVAC=$(command -v javac)
AAPT2=$(command -v aapt2); CLANG=$(command -v clang)
for a in "$JAVA" "$JAVAC" "$AAPT2" "$CLANG"; do [ -x "$a" ] || hata "Missing: $a"; done
ok "Ready"

yaz "SDK"
export ANDROID_HOME="$HOME/android-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
mkdir -p "$ANDROID_HOME/cmdline-tools"
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  cd "$ANDROID_HOME"
  wget "https://dl.google.com/android/repository/commandlinetools-linux-${CMDTOOLS}_latest.zip" -O ct.zip
  unzip -q ct.zip -d cmdline-tools
  rm -rf cmdline-tools/latest
  mv cmdline-tools/cmdline-tools cmdline-tools/latest
  rm -f ct.zip
fi
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
yes 2>/dev/null | sdkmanager --licenses >/dev/null 2>&1 || true
[ -f "$ANDROID_HOME/platforms/${PLATFORM}/android.jar" ] || yes 2>/dev/null | sdkmanager --install "platforms;${PLATFORM}" >/dev/null 2>&1
[ -d "$ANDROID_HOME/build-tools/${BT}" ] || yes 2>/dev/null | sdkmanager --install "build-tools;${BT}" >/dev/null 2>&1
ANDROID_JAR="$ANDROID_HOME/platforms/${PLATFORM}/android.jar"
[ -f "$ANDROID_JAR" ] || hata "android.jar missing"
R8DIR="$HOME/.valvehack-r8"; mkdir -p "$R8DIR"
R8JAR="$R8DIR/r8-${R8V}.jar"
[ -s "$R8JAR" ] || wget "$R8URL" -O "$R8JAR"
APKSIGNER="$ANDROID_HOME/build-tools/${BT}/lib/apksigner.jar"
[ -f "$APKSIGNER" ] || hata "apksigner.jar missing"
ok "SDK ready"

yaz "Project"
rm -rf "$PROJE"
mkdir -p "$PROJE/src/com/valvehack/modmenu"
mkdir -p "$PROJE/res/values" "$PROJE/res/drawable" "$PROJE/res/mipmap-anydpi-v26"
mkdir -p "$PROJE/assets" "$PROJE/cpp" "$PROJE/build"

cat > "$PROJE/AndroidManifest.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.valvehack.modmenu">
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"/>
    <application
        android:allowBackup="false"
        android:icon="@mipmap/ic_launcher"
        android:label="@string/app_name"
        android:theme="@style/AppTheme"
        android:hardwareAccelerated="true">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden|uiMode"
            android:launchMode="singleTop">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        <service
            android:name=".FloatingService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="overlay_service"/>
        </service>
    </application>
</manifest>
XEOF

cat > "$PROJE/res/values/strings.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">ValveHack</string>
</resources>
XEOF

cat > "$PROJE/res/values/themes.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="android:Theme.Material.NoActionBar">
        <item name="android:windowBackground">#050507</item>
        <item name="android:statusBarColor">#050507</item>
        <item name="android:navigationBarColor">#050507</item>
        <item name="android:colorAccent">#ff2a5c</item>
    </style>
</resources>
XEOF

cat > "$PROJE/res/drawable/ic_launcher_background.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#050507" android:pathData="M0,0h108v108h-108z"/>
</vector>
XEOF

cat > "$PROJE/res/drawable/ic_launcher_foreground.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#ff2a5c" android:pathData="M54,22 L82,38 L82,70 L54,86 L26,70 L26,38 Z"/>
    <path android:fillColor="#ffffff" android:pathData="M42,42 L48,42 L54,62 L60,42 L66,42 L57,72 L51,72 Z"/>
</vector>
XEOF

cat > "$PROJE/res/mipmap-anydpi-v26/ic_launcher.xml" <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/RootShell.java" <<'XEOF'
package com.valvehack.modmenu;

import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.atomic.AtomicInteger;

public final class RootShell {
    private static Process proc;
    private static OutputStream out;
    private static InputStream in;
    private static final Object LOCK = new Object();
    private static final AtomicInteger COUNTER = new AtomicInteger(0);
    private static volatile boolean available = false;
    private static long lastAttempt = 0L;

    private RootShell() {}

    public static boolean isAvailable() {
        return available && proc != null && proc.isAlive();
    }

    public static String exec(String cmd) { return exec(cmd, 20000L); }

    public static String exec(String cmd, long timeoutMs) {
        synchronized (LOCK) {
            if (!ensureShell()) return "ERR:no-root";
            try {
                String marker = "__VH" + COUNTER.incrementAndGet()
                        + "X" + System.nanoTime() + "__";
                String payload = cmd + "\necho " + marker + "\n";
                out.write(payload.getBytes("UTF-8"));
                out.flush();

                StringBuilder sb = new StringBuilder(256);
                byte[] buf = new byte[2048];
                long deadline = System.currentTimeMillis() + timeoutMs;
                while (System.currentTimeMillis() < deadline) {
                    int avail = in.available();
                    if (avail > 0) {
                        int n = in.read(buf, 0, Math.min(avail, buf.length));
                        if (n > 0) {
                            sb.append(new String(buf, 0, n, "UTF-8"));
                            int idx = sb.indexOf(marker);
                            if (idx >= 0) return sb.substring(0, idx).trim();
                        }
                    } else {
                        if (proc == null || !proc.isAlive()) break;
                        try { Thread.sleep(10); } catch (InterruptedException e) { break; }
                    }
                }
                return sb.toString().trim();
            } catch (Exception e) {
                shutdown();
                available = false;
                return "ERR:" + e.getMessage();
            }
        }
    }

    private static boolean ensureShell() {
        if (proc != null && proc.isAlive() && in != null && out != null) return true;
        long now = System.currentTimeMillis();
        if (now - lastAttempt < 800) return false;
        lastAttempt = now;
        shutdown();

        try {
            Process p = new ProcessBuilder("su", "-c", "sh").start();
            proc = p;
            out = p.getOutputStream();
            in = p.getInputStream();

            final Process fp = p;
            Thread drain = new Thread(() -> {
                try (InputStream es = fp.getErrorStream()) {
                    byte[] b = new byte[1024];
                    while (es.read(b) >= 0) { }
                } catch (Exception ignored) {}
            }, "vh-su-stderr");
            drain.setDaemon(true);
            drain.start();

            String ready = "__VHREADY" + System.nanoTime() + "__";
            out.write("exec 2>&1\n".getBytes("UTF-8")); out.write(("echo " + ready + "\n").getBytes("UTF-8"));
            out.flush();

            StringBuilder sb = new StringBuilder(64);
            byte[] buf = new byte[512];
            long deadline = System.currentTimeMillis() + 15000L;
            while (System.currentTimeMillis() < deadline) {
                if (proc == null || !proc.isAlive()) { shutdown(); return false; }
                int avail = in.available();
                if (avail > 0) {
                    int n = in.read(buf, 0, Math.min(avail, buf.length));
                    if (n > 0) {
                        sb.append(new String(buf, 0, n, "UTF-8"));
                        if (sb.indexOf(ready) >= 0) {
                            available = true;
                            return true;
                        }
                    }
                } else {
                    try { Thread.sleep(20); } catch (InterruptedException e) { break; }
                }
            }
            shutdown();
            return false;
        } catch (Exception e) {
            shutdown();
            return false;
        }
    }

    public static void shutdown() {
        try { if (out != null) out.close(); } catch (Exception ignored) {}
        try { if (in != null) in.close(); } catch (Exception ignored) {}
        try { if (proc != null) proc.destroy(); } catch (Exception ignored) {}
        proc = null; out = null; in = null; available = false;
    }

    public static String sq(String s) {
        if (s == null) return "''";
        if (s.matches("[A-Za-z0-9_\\-./=:+@]+")) return s;
        return "'" + s.replace("'", "'\\''") + "'";
    }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/LglSwitch.java" <<'XEOF'
package com.valvehack.modmenu;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.RectF;
import android.util.AttributeSet;
import android.view.HapticFeedbackConstants;
import android.view.View;
import android.view.animation.DecelerateInterpolator;

public class LglSwitch extends View {
    public interface OnChangeListener { void onChanged(LglSwitch v, boolean checked); }

    private final Paint trackPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint thumbPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final RectF track = new RectF();

    private boolean checked;
    private float pos;
    private OnChangeListener listener;
    private ValueAnimator anim;

    private static final int OFF   = 0xFF2A2D36;
    private static final int ON    = 0xFFFF2A5C;
    private static final int THUMB = 0xFFFFFFFF;

    public LglSwitch(Context c) { super(c); init(); }
    public LglSwitch(Context c, AttributeSet a) { super(c, a); init(); }

    private void init() {
        trackPaint.setStyle(Paint.Style.FILL);
        thumbPaint.setStyle(Paint.Style.FILL);
        thumbPaint.setColor(THUMB);
        thumbPaint.setShadowLayer(dp(3), 0, dp(1.5f), 0x66000000);
        setLayerType(LAYER_TYPE_SOFTWARE, null);
        setClickable(true);
        setFocusable(true);
        setOnClickListener(v -> {
            v.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK);
            setChecked(!checked, true);
        });
    }

    private float dp(float v) { return v * getResources().getDisplayMetrics().density; }

    @Override protected void onMeasure(int w, int h) {
        setMeasuredDimension((int) dp(44), (int) dp(26));
    }

    @Override protected void onDraw(Canvas cv) {
        float w = getWidth(), h = getHeight();
        float th = dp(24);
        float tw = dp(44);
        float left = (w - tw) / 2f, top = (h - th) / 2f;
        track.set(left, top, left + tw, top + th);

        trackPaint.setColor(blend(OFF, ON, pos));
        cv.drawRoundRect(track, th / 2f, th / 2f, trackPaint);

        float td = th - dp(4);
        float tS = track.left + dp(2);
        float tE = track.right - td - dp(2);
        float tx = tS + (tE - tS) * pos;
        float ty = track.top + dp(2);
        cv.drawCircle(tx + td / 2f, ty + td / 2f, td / 2f, thumbPaint);
    }

    private int blend(int a, int b, float t) {
        int ar = (a >> 16) & 0xFF, ag = (a >> 8) & 0xFF, ab = a & 0xFF;
        int br = (b >> 16) & 0xFF, bg = (b >> 8) & 0xFF, bb = b & 0xFF;
        return 0xFF000000
                | (((int)(ar + (br - ar) * t)) << 16)
                | (((int)(ag + (bg - ag) * t)) << 8)
                | ((int)(ab + (bb - ab) * t));
    }

    public boolean isChecked() { return checked; }
    public void setChecked(boolean v) { setChecked(v, false); }
    public void setChecked(boolean v, boolean notify) {
        boolean o = checked;
        checked = v;
        if (anim != null) anim.cancel();
        anim = ValueAnimator.ofFloat(pos, v ? 1f : 0f);
        anim.setDuration(200);
        anim.setInterpolator(new DecelerateInterpolator());
        anim.addUpdateListener(a -> { pos = (float) a.getAnimatedValue(); invalidate(); });
        anim.start();
        if (notify && listener != null && o != v) listener.onChanged(this, v);
    }
    public void setOnChangeListener(OnChangeListener l) { listener = l; }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/Prefs.java" <<'XEOF'
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
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/DebugLog.java" <<'XEOF'
package com.valvehack.modmenu;
import android.content.Context;
import java.io.*;
import java.nio.charset.StandardCharsets;
public final class DebugLog {
    private DebugLog() {}
    private static File f(Context c) { return new File(c.getCacheDir(), "valvehack.log"); }
    public static synchronized void write(Context c, String t) {
        try (FileOutputStream o = new FileOutputStream(f(c), true)) {
            o.write((new java.util.Date() + " " + t + "\n").getBytes(StandardCharsets.UTF_8));
        } catch (Exception ignored) {}
    }
    public static synchronized String read(Context c, int max) {
        StringBuilder sb = new StringBuilder();
        try (BufferedReader br = new BufferedReader(new InputStreamReader(new FileInputStream(f(c)), StandardCharsets.UTF_8))) {
            String[] ring = new String[Math.max(1, max)];
            int n = 0; String l;
            while ((l = br.readLine()) != null) { ring[n % ring.length] = l; n++; }
            int s = Math.max(0, n - ring.length);
            for (int i = s; i < n; i++) if (ring[i % ring.length] != null) sb.append(ring[i % ring.length]).append('\n');
        } catch (Exception ignored) {}
        return sb.toString().trim();
    }
    public static synchronized void clear(Context c) { try { f(c).delete(); } catch (Exception ignored) {} }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/NativeRunner.java" <<'XEOF'
package com.valvehack.modmenu;
import android.content.Context;
import java.io.*;
public final class NativeRunner {
    private static volatile File bin = null;
    private NativeRunner() {}
    public static File prepare(Context ctx) {
        File b = bin;
        if (b != null && b.exists()) return b;
        synchronized (NativeRunner.class) {
            b = bin;
            if (b != null && b.exists()) return b;
            try {
                File d = new File(ctx.getFilesDir(), "bin");
                if (!d.exists()) d.mkdirs();
                File f = new File(d, "valvehack");
                try (InputStream is = ctx.getAssets().open("valvehack");
                     OutputStream os = new FileOutputStream(f)) {
                    byte[] buf = new byte[32768];
                    int r;
                    while ((r = is.read(buf)) > 0) os.write(buf, 0, r);
                }
                f.setExecutable(true, false);
                bin = f;
                return f;
            } catch (Exception e) {
                DebugLog.write(ctx, "bin err " + e);
                return null;
            }
        }
    }
    public static String run(Context ctx, String... args) {
        File b = prepare(ctx);
        if (b == null) return "ERR:binary";
        StringBuilder cmd = new StringBuilder(b.getAbsolutePath());
        for (String a : args) cmd.append(' ').append(RootShell.sq(a));
        return RootShell.exec(cmd.toString());
    }
    public static String shell(String cmd) { return RootShell.exec(cmd); }
    public static boolean hasRoot() {
        if (RootShell.isAvailable()) return true;
        String out = RootShell.exec("id");
        return out.contains("uid=0");
    }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/Dokunma.java" <<'XEOF'
package com.valvehack.modmenu;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.os.Build;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.view.MotionEvent;
import android.view.View;

public final class Dokunma {
    private static Vibrator vib;
    private Dokunma() {}

    public static int dp(Context c, int v) {
        return (int)(v * c.getResources().getDisplayMetrics().density);
    }

    public static GradientDrawable box(Context c, int bg, int stroke, int radius, int strokeW) {
        GradientDrawable g = new GradientDrawable();
        g.setCornerRadius(dp(c, radius));
        g.setColor(bg);
        if (stroke != 0) g.setStroke(dp(c, strokeW), stroke);
        return g;
    }

    public static GradientDrawable vertical(Context c, int top, int bottom, int radius, int stroke, int strokeW) {
        GradientDrawable g = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[]{top, bottom});
        g.setCornerRadius(dp(c, radius));
        if (stroke != 0) g.setStroke(dp(c, strokeW), stroke);
        return g;
    }

    public static RippleDrawable ripple(Context c, int bg, int stroke, int rip, int r, int sw) {
        GradientDrawable content = box(c, bg, stroke, r, sw);
        GradientDrawable mask = new GradientDrawable();
        mask.setCornerRadius(dp(c, r));
        mask.setColor(Color.WHITE);
        return new RippleDrawable(ColorStateList.valueOf(rip), content, mask);
    }

    public static RippleDrawable rippleGrad(Context c, int top, int bottom, int stroke, int rip, int r, int sw) {
        GradientDrawable content = vertical(c, top, bottom, r, stroke, sw);
        GradientDrawable mask = new GradientDrawable();
        mask.setCornerRadius(dp(c, r));
        mask.setColor(Color.WHITE);
        return new RippleDrawable(ColorStateList.valueOf(rip), content, mask);
    }

    public static void press(View v, Context c) {
        v.setOnTouchListener((view, e) -> {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    view.animate().scaleX(0.96f).scaleY(0.96f).setDuration(90).start(); break;
                case MotionEvent.ACTION_UP:
                    view.animate().scaleX(1f).scaleY(1f).setDuration(90).start();
                    haptic(c); break;
                case MotionEvent.ACTION_CANCEL:
                    view.animate().scaleX(1f).scaleY(1f).setDuration(90).start(); break;
            }
            return false;
        });
    }

    public static void fade(View v) {
        v.setOnTouchListener((view, e) -> {
            switch (e.getActionMasked()) {
                case MotionEvent.ACTION_DOWN: view.setAlpha(0.5f); break;
                case MotionEvent.ACTION_UP: case MotionEvent.ACTION_CANCEL: view.setAlpha(1f); break;
            }
            return false;
        });
    }

    private static Vibrator vib(Context c) {
        Vibrator v = vib;
        if (v == null) {
            synchronized (Dokunma.class) {
                v = vib;
                if (v == null) {
                    v = (Vibrator) c.getApplicationContext().getSystemService(Context.VIBRATOR_SERVICE);
                    vib = v;
                }
            }
        }
        return v;
    }

    public static void haptic(Context c) {
        if (!Prefs.haptics(c)) return;
        try {
            Vibrator v = vib(c);
            if (v == null || !v.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK));
            else v.vibrate(15);
        } catch (Exception ignored) {}
    }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/Yamalar.java" <<'XEOF'
package com.valvehack.modmenu;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public final class Yamalar {

    public static final String AMONG_US = "com.innersloth.spacemafia";

    public static class Patch {
        public String id;
        public String name;
        public String library;
        public String rva;
        public String patched;
        public String original;
        public String sig;
        public String type;

        public Patch() {}
        public Patch(String name, String library, String rva, String patched, String original) {
            this(name, library, rva, patched, original, null);
        }
        public Patch(String name, String library, String rva, String patched, String original, String sig) {
            this.id = UUID.randomUUID().toString();
            this.name = name;
            this.library = library;
            this.rva = rva;
            this.patched = patched;
            this.original = original;
            this.sig = sig;
            this.type = "byte";
        }
        public Patch(String name, String type) {
            this.id = UUID.randomUUID().toString();
            this.name = name;
            this.type = type;
            this.library = "libil2cpp.so";
            this.rva = "";
            this.patched = "";
            this.original = "";
        }
    }

    private static SharedPreferences cached;
    private static List<Patch> cachedList;

    private static SharedPreferences sp(Context c) {
        SharedPreferences s = cached;
        if (s == null) {
            synchronized (Yamalar.class) {
                s = cached;
                if (s == null) {
                    s = c.getApplicationContext().getSharedPreferences("valvehack_patches_v7", Context.MODE_PRIVATE);
                    cached = s;
                }
            }
        }
        return s;
    }

    public static void loadDefaults(Context c) {
        if (sp(c).contains("data")) return;
        List<Patch> list = new ArrayList<>(12);
        list.add(new Patch("No Clip", "noclip"));
        list.add(new Patch("Sabotage All", "sabotage-all"));
        list.add(new Patch("Chat Spam", "chat-spam"));
        list.add(new Patch("All Cosmetics", "libil2cpp.so",
                "241062C", "20008052c0035fd6", "fe0f1df8f65701a9", "69 ba 41 14 ef 25 ec 97 ?? ?? ?? ?? ?? ?? ?? ?? f4 4f 02 a9 d6 47 01 90"));
        list.add(new Patch("Red Impostor Names", "libil2cpp.so",
                "21E4380", "05000014", "a0000054", "20 01 3f d6 9f 02 15 6b ?? ?? ?? ?? 01 10 2e 1e 02 10 2e 1e"));
        list.add(new Patch("Full Bright", "libil2cpp.so",
                "2253108", "0059a8520000271ec0035fd6", "eb2bbb6de923016dfe1300f9", "39 1b f3 97 3a 1b f3 97 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? f6 57 03 a9 f4 4f 04 a9"));
        list.add(new Patch("Level 666", "libil2cpp.so",
                "21DD800", "33538052", "f303012a", "a8 0a 6c 39 d6 fa 40 f9 ?? ?? ?? ?? f4 03 00 aa 28 01 00 37"));
        list.add(new Patch("Dead Chat", "libil2cpp.so",
                "20FA9A8", "1f2003d5", "c8160034", "d4 22 00 b4 88 e2 41 39 ?? ?? ?? ?? e0 03 13 aa 56 fe ff 97"));
        list.add(new Patch("In-Game Chat", "libil2cpp.so",
                "20F9934", "33008052", "f303012a", "c8 c2 4f 39 b5 96 46 f9 ?? ?? ?? ?? f4 03 00 aa e8 01 00 37"));
        list.add(new Patch("4 Impostors", "libil2cpp.so",
                "2231E18", "80008052c0035fd6", "fe57bea9f44f01a9", "80 00 1f d6 f4 9f f3 97 ?? ?? ?? ?? ?? ?? ?? ?? b4 56 01 d0 88 46 78 39"));
        save(c, list);
    }

    public static synchronized List<Patch> list(Context c) {
        loadDefaults(c);
        if (cachedList != null) return new ArrayList<>(cachedList);
        List<Patch> out = new ArrayList<>(12);
        try {
            JSONObject root = new JSONObject(sp(c).getString("data", "{}"));
            if (root.has(AMONG_US)) {
                JSONArray arr = root.getJSONArray(AMONG_US);
                for (int i = 0; i < arr.length(); i++) {
                    JSONObject o = arr.getJSONObject(i);
                    Patch y = new Patch();
                    y.id = o.getString("id");
                    y.name = o.getString("name");
                    y.library = o.getString("library");
                    y.rva = o.getString("rva");
                    y.patched = o.getString("patched");
                    y.original = o.getString("original");
                    y.type = o.optString("type", "byte");
                    y.sig = o.optString("sig", "");
                    out.add(y);
                }
            }
        } catch (Exception ignored) {}
        cachedList = out;
        return new ArrayList<>(out);
    }

    public static synchronized void save(Context c, List<Patch> list) {
        cachedList = new ArrayList<>(list);
        try {
            JSONObject root = new JSONObject();
            JSONArray arr = new JSONArray();
            for (Patch y : list) {
                JSONObject o = new JSONObject();
                o.put("id", y.id);
                o.put("name", y.name);
                o.put("library", y.library);
                o.put("rva", y.rva);
                o.put("patched", y.patched);
                o.put("original", y.original);
                o.put("sig", y.sig != null ? y.sig : "");
                o.put("type", y.type);
                arr.put(o);
            }
            root.put(AMONG_US, arr);
            sp(c).edit().putString("data", root.toString()).apply();
        } catch (Exception ignored) {}
    }

    public static void add(Context c, Patch y) { List<Patch> l = list(c); l.add(y); save(c, l); }

    public static void remove(Context c, String id) {
        List<Patch> l = list(c);
        List<Patch> out = new ArrayList<>(l.size());
        for (Patch y : l) if (!y.id.equals(id)) out.add(y);
        save(c, out);
    }

    public static void update(Context c, Patch upd) {
        List<Patch> l = list(c);
        for (int i = 0; i < l.size(); i++) if (l.get(i).id.equals(upd.id)) { l.set(i, upd); break; }
        save(c, l);
    }

    public static void reset(Context c) {
        cachedList = null;
        sp(c).edit().remove("data").apply();
    }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/ProcList.java" <<'XEOF'
package com.valvehack.modmenu;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.drawable.Drawable;

public final class ProcList {
    private static String cachedName;
    private static Drawable cachedIcon;
    private static boolean cachedInstalled;
    private static boolean cachedValid;
    private ProcList() {}
    private static void refresh(Context ctx, String pkg) {
        if (cachedValid) return;
        synchronized (ProcList.class) {
            if (cachedValid) return;
            PackageManager pm = ctx.getPackageManager();
            try {
                ApplicationInfo ai = pm.getApplicationInfo(pkg, 0);
                cachedName = pm.getApplicationLabel(ai).toString();
                cachedIcon = pm.getApplicationIcon(pkg);
                cachedInstalled = true;
            } catch (Exception e) {
                cachedName = pkg;
                cachedIcon = null;
                cachedInstalled = false;
            }
            cachedValid = true;
        }
    }
    public static Drawable icon(Context ctx, String pkg) { refresh(ctx, pkg); return cachedIcon; }
    public static String name(Context ctx, String pkg) { refresh(ctx, pkg); return cachedName != null ? cachedName : pkg; }
    public static boolean installed(Context ctx, String pkg) { refresh(ctx, pkg); return cachedInstalled; }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/MainActivity.java" <<'XEOF'
package com.valvehack.modmenu;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.Button;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

public class MainActivity extends Activity {

    private static final int BG          = 0xFF0A0A0F;
    private static final int SURFACE     = 0xFF13131A;
    private static final int SURFACE_HI  = 0xFF1A1A24;
    private static final int SURFACE_DEEP= 0xFF07070B;
    private static final int ACCENT      = 0xFFFF2A5C;
    private static final int ACCENT_SOFT = 0x22FF2A5C;
    private static final int TEXT        = 0xFFF5F5F7;
    private static final int TEXT_DIM    = 0xFF8A8A99;
    private static final int TEXT_MUTE   = 0xFF55556A;
    private static final int LINE        = 0xFF23232E;
    private static final int OK          = 0xFF34D399;
    private static final int WARN        = 0xFFFBBF24;

    private final Handler ui = new Handler(Looper.getMainLooper());
    private boolean showPatches = false;
    private float density = 1f;

    private TextView rootStatus, overlayStatus, serviceStatus;
    private Button mainBtn;

    private int dp(int v) { return (int)(v * density); }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        density = getResources().getDisplayMetrics().density;
        Yamalar.loadDefaults(this);
        render();
    }

    @Override
    public void onBackPressed() {
        if (showPatches) { showPatches = false; render(); }
        else super.onBackPressed();
    }

    private void render() { if (showPatches) patchesScreen(); else homeScreen(); }

    private void homeScreen() {
        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(BG);
        sv.setFillViewport(true);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(44), dp(20), dp(32));
        root.setAlpha(0f);
        root.animate().alpha(1f).setDuration(260).start();

        root.addView(buildHeader());

        LinearLayout strip = new LinearLayout(this);
        strip.setOrientation(LinearLayout.HORIZONTAL);
        strip.setPadding(0, dp(30), 0, 0);
        root.addView(strip);

        LinearLayout c1 = statusChip("ROOT",     "...",     WARN);
        LinearLayout c2 = statusChip("OVERLAY",  "...",     WARN);
        LinearLayout c3 = statusChip("SERVICE",  "stopped", TEXT_MUTE);
        rootStatus     = (TextView) c1.getChildAt(1);
        overlayStatus  = (TextView) c2.getChildAt(1);
        serviceStatus  = (TextView) c3.getChildAt(1);

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        lp.setMargins(0, 0, dp(8), 0);
        strip.addView(c1, lp);
        LinearLayout.LayoutParams lp2 = new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f);
        lp2.setMargins(0, 0, dp(8), 0);
        strip.addView(c2, lp2);
        strip.addView(c3, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        mainBtn = new Button(this);
        mainBtn.setAllCaps(false);
        mainBtn.setText("START SERVICE");
        mainBtn.setTextColor(Color.WHITE);
        mainBtn.setTextSize(14);
        mainBtn.setTypeface(null, Typeface.BOLD);
        mainBtn.setLetterSpacing(0.18f);
        mainBtn.setStateListAnimator(null);
        mainBtn.setBackground(Dokunma.rippleGrad(this, 0xFFFF3D6B, 0xFFE01F4E, 0, 0x44FFFFFF, 20, 0));
        mainBtn.setElevation(dp(6));
        mainBtn.setOnClickListener(v -> onPrimary());
        Dokunma.press(mainBtn, this);

        LinearLayout.LayoutParams cta = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(60));
        cta.setMargins(0, dp(22), 0, 0);
        root.addView(mainBtn, cta);

        root.addView(sectionLabel("TARGET GAME"));
        root.addView(gameCard());
        sv.addView(root);
        setContentView(sv);

        refreshAll();
        new Thread(() -> {
            final boolean ok = NativeRunner.hasRoot();
            ui.post(() -> {
                rootStatus.setText(ok ? "granted" : "denied");
                rootStatus.setTextColor(ok ? OK : ACCENT);
            });
        }, "vh-root").start();
    }

    private View buildHeader() {
        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);

        FrameLayout mark = new FrameLayout(this);
        mark.setBackground(Dokunma.vertical(this, 0xFFFF3D6B, 0xFFB01040, 16, 0, 0));
        mark.setElevation(dp(8));
        TextView lg = new TextView(this);
        lg.setText("V");
        lg.setTextColor(Color.WHITE);
        lg.setTextSize(24);
        lg.setTypeface(null, Typeface.BOLD);
        lg.setGravity(Gravity.CENTER);
        mark.addView(lg, new FrameLayout.LayoutParams(dp(52), dp(52), Gravity.CENTER));
        header.addView(mark, new LinearLayout.LayoutParams(dp(52), dp(52)));

        LinearLayout titles = new LinearLayout(this);
        titles.setOrientation(LinearLayout.VERTICAL);
        titles.setPadding(dp(16), 0, 0, 0);

        TextView t1 = new TextView(this);
        t1.setText("VALVEHACK");
        t1.setTextColor(TEXT);
        t1.setTextSize(22);
        t1.setTypeface(null, Typeface.BOLD);
        t1.setLetterSpacing(0.22f);
        titles.addView(t1);

        TextView t2 = new TextView(this);
        t2.setText("MOD MENU  ·  v5.0.0");
        t2.setTextColor(ACCENT);
        t2.setTextSize(10);
        t2.setLetterSpacing(0.4f);
        t2.setTypeface(null, Typeface.BOLD);
        t2.setPadding(0, dp(4), 0, 0);
        titles.addView(t2);
        header.addView(titles, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView gear = new TextView(this);
        gear.setText("⚙");
        gear.setTextColor(TEXT);
        gear.setTextSize(20);
        gear.setGravity(Gravity.CENTER);
        gear.setBackground(Dokunma.ripple(this, SURFACE, LINE, ACCENT_SOFT, 14, 1));
        gear.setOnClickListener(v -> { Dokunma.haptic(this); settingsDialog(); });
        Dokunma.press(gear, this);
        header.addView(gear, new LinearLayout.LayoutParams(dp(44), dp(44)));
        return header;
    }

    private LinearLayout statusChip(String label, String value, int valueColor) {
        LinearLayout chip = new LinearLayout(this);
        chip.setOrientation(LinearLayout.VERTICAL);
        chip.setPadding(dp(14), dp(14), dp(14), dp(14));
        chip.setBackground(Dokunma.box(this, SURFACE, LINE, 16, 1));
        chip.setElevation(dp(1));

        TextView l = new TextView(this);
        l.setText(label);
        l.setTextColor(TEXT_MUTE);
        l.setTextSize(9);
        l.setTypeface(null, Typeface.BOLD);
        l.setLetterSpacing(0.3f);
        chip.addView(l);

        TextView v = new TextView(this);
        v.setText(value);
        v.setTextColor(valueColor);
        v.setTextSize(13);
        v.setTypeface(null, Typeface.BOLD);
        v.setPadding(0, dp(6), 0, 0);
        chip.addView(v);
        return chip;
    }

    private TextView sectionLabel(String text) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextColor(TEXT_MUTE);
        t.setTextSize(10);
        t.setTypeface(null, Typeface.BOLD);
        t.setLetterSpacing(0.4f);
        t.setPadding(dp(4), dp(30), dp(4), dp(12));
        return t;
    }

    private View gameCard() {
        boolean installed = ProcList.installed(this, Yamalar.AMONG_US);

        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setPadding(dp(16), dp(16), dp(14), dp(16));
        card.setBackground(Dokunma.ripple(this, SURFACE, LINE, ACCENT_SOFT, 20, 1));
        card.setElevation(dp(2));

        FrameLayout tile = new FrameLayout(this);
        tile.setBackground(Dokunma.box(this, SURFACE_HI, LINE, 16, 1));
        ImageView iv = new ImageView(this);
        Drawable d = ProcList.icon(this, Yamalar.AMONG_US);
        if (d != null) iv.setImageDrawable(d);
        else iv.setImageResource(android.R.drawable.sym_def_app_icon);
        tile.addView(iv, new FrameLayout.LayoutParams(dp(40), dp(40), Gravity.CENTER));
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(dp(56), dp(56));
        tlp.setMargins(0, 0, dp(14), 0);
        card.addView(tile, tlp);

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);

        TextView name = new TextView(this);
        name.setText(ProcList.name(this, Yamalar.AMONG_US));
        name.setTextColor(TEXT);
        name.setTextSize(16);
        name.setTypeface(null, Typeface.BOLD);
        info.addView(name);

        TextView sub = new TextView(this);
        sub.setText(installed ? (Yamalar.list(this).size() + " patches available") : "Not installed");
        sub.setTextColor(installed ? TEXT_DIM : ACCENT);
        sub.setTextSize(11);
        sub.setPadding(0, dp(4), 0, 0);
        info.addView(sub);
        card.addView(info, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView pill = new TextView(this);
        pill.setText(installed ? "OPEN  ›" : "N/A");
        pill.setTextColor(installed ? ACCENT : TEXT_MUTE);
        pill.setTextSize(10);
        pill.setTypeface(null, Typeface.BOLD);
        pill.setLetterSpacing(0.2f);
        pill.setGravity(Gravity.CENTER);
        pill.setPadding(dp(14), dp(10), dp(14), dp(10));
        pill.setBackground(Dokunma.box(this, installed ? ACCENT_SOFT : SURFACE_HI,
                installed ? ACCENT : LINE, 12, 1));
        card.addView(pill);

        if (installed) {
            card.setOnClickListener(v -> {
                Dokunma.haptic(this);
                showPatches = true;
                render();
            });
        }
        return card;
    }

    private void onPrimary() {
        Dokunma.haptic(this);

        if (FloatingService.active) {
            stopService(new Intent(this, FloatingService.class));
            ui.postDelayed(this::refreshAll, 300);
            toast("Service stopped");
            return;
        }

        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
            toast("Grant overlay permission");
            startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:" + getPackageName())));
            return;
        }

        if (!ProcList.installed(this, Yamalar.AMONG_US)) {
            toast("Among Us not installed");
            return;
        }

        if (mainBtn != null) {
            mainBtn.setEnabled(false);
            mainBtn.setText("CHECKING...");
        }

        new Thread(() -> {
            final boolean root = NativeRunner.hasRoot();
            ui.post(() -> {
                if (mainBtn != null) { mainBtn.setEnabled(true); refreshAll(); }
                if (!root) { toast("Root required"); return; }
                Intent s = new Intent(this, FloatingService.class);
                if (Build.VERSION.SDK_INT >= 26) startForegroundService(s);
                else startService(s);
                ui.postDelayed(this::refreshAll, 500);
                toast("Started");
            });
        }, "vh-primary").start();
    }

    private void refreshAll() {
        if (overlayStatus == null) return;
        boolean ov = Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this);
        overlayStatus.setText(ov ? "granted" : "required");
        overlayStatus.setTextColor(ov ? OK : ACCENT);

        boolean sv = FloatingService.active;
        serviceStatus.setText(sv ? "active" : "stopped");
        serviceStatus.setTextColor(sv ? OK : TEXT_MUTE);

        if (mainBtn != null) {
            if (sv) {
                mainBtn.setText("STOP SERVICE");
                mainBtn.setBackground(Dokunma.rippleGrad(this, 0xFF2A2A38, 0xFF1E1E28, 0, 0x44FFFFFF, 20, 0));
            } else {
                mainBtn.setText("START SERVICE");
                mainBtn.setBackground(Dokunma.rippleGrad(this, 0xFFFF3D6B, 0xFFE01F4E, 0, 0x44FFFFFF, 20, 0));
            }
        }
    }

    private void patchesScreen() {
        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(BG);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(20), dp(44), dp(20), dp(32));
        root.setAlpha(0f);
        root.animate().alpha(1f).setDuration(220).start();

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);

        TextView back = new TextView(this);
        back.setText("‹");
        back.setTextColor(TEXT);
        back.setTextSize(28);
        back.setGravity(Gravity.CENTER);
        back.setBackground(Dokunma.ripple(this, SURFACE, LINE, ACCENT_SOFT, 12, 1));
        back.setOnClickListener(v -> { Dokunma.haptic(this); showPatches = false; render(); });
        Dokunma.press(back, this);
        header.addView(back, new LinearLayout.LayoutParams(dp(44), dp(44)));

        FrameLayout tile = new FrameLayout(this);
        tile.setBackground(Dokunma.box(this, SURFACE_HI, LINE, 14, 1));
        ImageView iv = new ImageView(this);
        Drawable d = ProcList.icon(this, Yamalar.AMONG_US);
        if (d != null) iv.setImageDrawable(d);
        tile.addView(iv, new FrameLayout.LayoutParams(dp(34), dp(34), Gravity.CENTER));
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(dp(48), dp(48));
        tlp.setMargins(dp(14), 0, dp(14), 0);
        header.addView(tile, tlp);

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        TextView h1 = new TextView(this);
        h1.setText(ProcList.name(this, Yamalar.AMONG_US));
        h1.setTextColor(TEXT);
        h1.setTextSize(17);
        h1.setTypeface(null, Typeface.BOLD);
        info.addView(h1);
        TextView h2 = new TextView(this);
        h2.setText(Yamalar.AMONG_US);
        h2.setTextColor(TEXT_MUTE);
        h2.setTextSize(10);
        h2.setPadding(0, dp(3), 0, 0);
        info.addView(h2);
        header.addView(info, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));
        root.addView(header);

        LinearLayout sh = new LinearLayout(this);
        sh.setOrientation(LinearLayout.HORIZONTAL);
        sh.setGravity(Gravity.CENTER_VERTICAL);
        sh.setPadding(dp(4), dp(30), dp(4), dp(14));

        TextView shl = new TextView(this);
        shl.setText("PATCHES");
        shl.setTextColor(TEXT_MUTE);
        shl.setTextSize(10);
        shl.setTypeface(null, Typeface.BOLD);
        shl.setLetterSpacing(0.4f);
        sh.addView(shl, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView add = new TextView(this);
        add.setText("+  NEW PATCH");
        add.setTextColor(ACCENT);
        add.setTextSize(11);
        add.setTypeface(null, Typeface.BOLD);
        add.setLetterSpacing(0.15f);
        add.setGravity(Gravity.CENTER);
        add.setPadding(dp(16), dp(10), dp(16), dp(10));
        add.setBackground(Dokunma.ripple(this, ACCENT_SOFT, ACCENT, 0x44FF2A5C, 12, 1));
        add.setOnClickListener(v -> { Dokunma.haptic(this); patchDialog(null); });
        Dokunma.press(add, this);
        sh.addView(add);
        root.addView(sh);

        List<Yamalar.Patch> list = Yamalar.list(this);
        if (list.isEmpty()) {
            LinearLayout empty = new LinearLayout(this);
            empty.setOrientation(LinearLayout.VERTICAL);
            empty.setGravity(Gravity.CENTER);
            empty.setPadding(0, dp(80), 0, dp(80));
            TextView e = new TextView(this);
            e.setText("No patches yet");
            e.setTextColor(TEXT_DIM);
            e.setTextSize(14);
            empty.addView(e);
            TextView e2 = new TextView(this);
            e2.setText("Tap  + NEW PATCH  to create one");
            e2.setTextColor(TEXT_MUTE);
            e2.setTextSize(11);
            e2.setPadding(0, dp(8), 0, 0);
            empty.addView(e2);
            root.addView(empty);
        } else {
            for (Yamalar.Patch y : list) {
                LinearLayout.LayoutParams clp = new LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
                clp.setMargins(0, 0, 0, dp(10));
                root.addView(patchCard(y), clp);
            }
        }

        sv.addView(root);
        setContentView(sv);
    }

    private View patchCard(final Yamalar.Patch y) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.HORIZONTAL);
        card.setGravity(Gravity.CENTER_VERTICAL);
        card.setPadding(dp(18), dp(16), dp(14), dp(16));
        card.setBackground(Dokunma.ripple(this, SURFACE, LINE, ACCENT_SOFT, 18, 1));
        card.setElevation(dp(1));

        LinearLayout text = new LinearLayout(this);
        text.setOrientation(LinearLayout.VERTICAL);

        TextView name = new TextView(this);
        name.setText(y.name);
        name.setTextColor(TEXT);
        name.setTextSize(15);
        name.setTypeface(null, Typeface.BOLD);
        text.addView(name);

        TextView sub = new TextView(this);
        if ("noclip".equals(y.type)) sub.setText("SPECIAL  ·  IL2CPP API");
        else if ("sabotage-all".equals(y.type)) sub.setText("SPECIAL  ·  RPC + DOORS");
        else if ("chat-spam".equals(y.type)) sub.setText("SPECIAL  ·  RpcSendChat");
        else sub.setText("RVA  " + y.rva);
        sub.setTextColor(("noclip".equals(y.type) || "sabotage-all".equals(y.type) || "chat-spam".equals(y.type)) ? ACCENT : TEXT_DIM);
        sub.setTextSize(10);
        sub.setTypeface(Typeface.MONOSPACE);
        sub.setPadding(0, dp(5), 0, 0);
        text.addView(sub);
        card.addView(text, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView edit = new TextView(this);
        edit.setText("Edit");
        edit.setTextColor(TEXT);
        edit.setTextSize(11);
        edit.setTypeface(null, Typeface.BOLD);
        edit.setGravity(Gravity.CENTER);
        edit.setPadding(dp(16), dp(10), dp(16), dp(10));
        edit.setBackground(Dokunma.ripple(this, SURFACE_HI, LINE, ACCENT_SOFT, 12, 1));
        edit.setOnClickListener(v -> { Dokunma.haptic(this); patchDialog(y); });
        Dokunma.press(edit, this);
        card.addView(edit);
        return card;
    }

    private void patchDialog(final Yamalar.Patch existing) {
        final boolean editing = existing != null;
        if (editing && "chat-spam".equals(existing.type)) { chatDialog(); return; }
        if (editing && ("noclip".equals(existing.type) || "sabotage-all".equals(existing.type))) { toast("This patch is special"); return; }

        ScrollView sv = new ScrollView(this);
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        ll.setPadding(dp(22), dp(24), dp(22), dp(8));

        TextView title = new TextView(this);
        title.setText(editing ? "EDIT PATCH" : "NEW PATCH");
        title.setTextColor(ACCENT);
        title.setTextSize(11);
        title.setLetterSpacing(0.4f);
        title.setTypeface(null, Typeface.BOLD);
        title.setPadding(0, 0, 0, dp(6));
        ll.addView(title);

        TextView sub = new TextView(this);
        sub.setText(editing ? "Modify the byte patch configuration" : "Define a memory byte patch");
        sub.setTextColor(TEXT_MUTE);
        sub.setTextSize(11);
        sub.setPadding(0, 0, 0, dp(20));
        ll.addView(sub);

        final EditText name     = field(ll, "PATCH NAME",      editing ? existing.name : "");
        final EditText library  = field(ll, "LIBRARY",         editing ? existing.library : "libil2cpp.so");
        final EditText rva      = field(ll, "RVA  (HEX)",      editing ? existing.rva : "");
        final EditText patched  = field(ll, "PATCHED BYTES",   editing ? existing.patched : "");
        final EditText original = field(ll, "ORIGINAL BYTES",  editing ? existing.original : "");
        sv.addView(ll);

        AlertDialog.Builder b = new AlertDialog.Builder(this);
        b.setView(sv);
        b.setPositiveButton("Save", null);
        b.setNegativeButton("Cancel", null);
        if (editing) b.setNeutralButton("Delete", (d, w) -> { Yamalar.remove(this, existing.id); render(); });

        final AlertDialog dialog = b.create();
        Window win = dialog.getWindow();
        if (win != null) win.setBackgroundDrawable(Dokunma.box(this, SURFACE_HI, LINE, 22, 1));
        dialog.show();

        dialog.getButton(DialogInterface.BUTTON_POSITIVE).setTextColor(ACCENT);
        dialog.getButton(DialogInterface.BUTTON_NEGATIVE).setTextColor(TEXT_DIM);
        dialog.getButton(DialogInterface.BUTTON_NEUTRAL).setTextColor(ACCENT);

        dialog.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(v -> {
            String n  = name.getText().toString().trim();
            String lb = library.getText().toString().trim();
            String r  = cleanHex(rva.getText().toString());
            String y  = cleanHex(patched.getText().toString());
            String o  = cleanHex(original.getText().toString());
            if (n.isEmpty() || lb.isEmpty() || r.isEmpty() || y.isEmpty() || o.isEmpty()) {
                toast("All fields required"); return;
            }
            if (y.length() != o.length()) { toast("Byte lengths must match"); return; }
            if (y.length() % 2 != 0) { toast("Hex must have even length"); return; }
            if (editing) {
                existing.name = n; existing.library = lb; existing.rva = r.toUpperCase();
                existing.patched = y.toLowerCase(); existing.original = o.toLowerCase();
                Yamalar.update(this, existing);
            } else {
                Yamalar.add(this, new Yamalar.Patch(n, lb, r.toUpperCase(), y.toLowerCase(), o.toLowerCase()));
            }
            render();
            dialog.dismiss();
        });
    }

    private void chatDialog() {
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        ll.setPadding(dp(22), dp(24), dp(22), dp(10));

        TextView t = new TextView(this);
        t.setText("CHAT SPAM");
        t.setTextColor(ACCENT);
        t.setTextSize(11);
        t.setLetterSpacing(0.4f);
        t.setTypeface(null, Typeface.BOLD);
        t.setPadding(0, 0, 0, dp(6));
        ll.addView(t);

        TextView s = new TextView(this);
        s.setText("One message per line - looping in order");
        s.setTextColor(TEXT_MUTE);
        s.setTextSize(11);
        s.setPadding(0, 0, 0, dp(16));
        ll.addView(s);

        TextView lbl1 = new TextView(this);
        lbl1.setText("MESSAGES");
        lbl1.setTextColor(TEXT_MUTE);
        lbl1.setTextSize(9);
        lbl1.setLetterSpacing(0.3f);
        lbl1.setTypeface(null, Typeface.BOLD);
        lbl1.setPadding(dp(4), 0, 0, dp(8));
        ll.addView(lbl1);

        final EditText ed = new EditText(this);
        ed.setText(Prefs.chatMessages(this));
        ed.setTextColor(TEXT);
        ed.setTextSize(13);
        ed.setTypeface(Typeface.MONOSPACE);
        ed.setBackground(Dokunma.box(this, SURFACE_DEEP, LINE, 12, 1));
        ed.setPadding(dp(16), dp(14), dp(16), dp(14));
        ed.setGravity(Gravity.TOP | Gravity.START);
        ll.addView(ed, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(180)));

        TextView lbl2 = new TextView(this);
        lbl2.setText("INTERVAL  (SECONDS, 1-60)");
        lbl2.setTextColor(TEXT_MUTE);
        lbl2.setTextSize(9);
        lbl2.setLetterSpacing(0.3f);
        lbl2.setTypeface(null, Typeface.BOLD);
        lbl2.setPadding(dp(4), dp(16), 0, dp(8));
        ll.addView(lbl2);

        final EditText itv = new EditText(this);
        itv.setText(String.valueOf(Prefs.chatInterval(this)));
        itv.setInputType(InputType.TYPE_CLASS_NUMBER);
        itv.setTextColor(TEXT);
        itv.setTextSize(13);
        itv.setTypeface(Typeface.MONOSPACE);
        itv.setSingleLine(true);
        itv.setBackground(Dokunma.box(this, SURFACE_DEEP, LINE, 12, 1));
        itv.setPadding(dp(16), dp(14), dp(16), dp(14));
        ll.addView(itv, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        AlertDialog.Builder b = new AlertDialog.Builder(this);
        b.setView(ll);
        b.setPositiveButton("Save", null);
        b.setNegativeButton("Cancel", null);
        final AlertDialog d = b.create();
        Window w = d.getWindow();
        if (w != null) w.setBackgroundDrawable(Dokunma.box(this, SURFACE_HI, LINE, 22, 1));
        d.show();
        d.getButton(DialogInterface.BUTTON_POSITIVE).setTextColor(ACCENT);
        d.getButton(DialogInterface.BUTTON_NEGATIVE).setTextColor(TEXT_DIM);
        d.getButton(DialogInterface.BUTTON_POSITIVE).setOnClickListener(v -> {
            String msgs = ed.getText().toString();
            int iv;
            try { iv = Integer.parseInt(itv.getText().toString().trim()); } catch (Exception e) { iv = 2; }
            iv = Math.max(1, Math.min(60, iv));
            Prefs.setChatMessages(this, msgs);
            Prefs.setChatInterval(this, iv);
            toast("Saved");
            d.dismiss();
        });
    }

    private EditText field(LinearLayout parent, String label, String def) {
        TextView l = new TextView(this);
        l.setText(label);
        l.setTextColor(TEXT_MUTE);
        l.setTextSize(9);
        l.setLetterSpacing(0.3f);
        l.setTypeface(null, Typeface.BOLD);
        l.setPadding(dp(4), dp(14), 0, dp(8));
        parent.addView(l);

        EditText e = new EditText(this);
        e.setText(def);
        e.setHint(label);
        e.setTextColor(TEXT);
        e.setHintTextColor(0xFF3A4450);
        e.setTextSize(13);
        e.setTypeface(Typeface.MONOSPACE);
        e.setSingleLine(true);
        e.setBackground(Dokunma.box(this, SURFACE_DEEP, LINE, 12, 1));
        e.setPadding(dp(16), dp(14), dp(16), dp(14));
        parent.addView(e, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        return e;
    }

    private String cleanHex(String s) {
        return s.replace("0x", "").replace("0X", "")
                .replace(" ", "").replace("\n", "").replace("\t", "").trim();
    }

    private void settingsDialog() {
        LinearLayout ll = new LinearLayout(this);
        ll.setOrientation(LinearLayout.VERTICAL);
        ll.setPadding(dp(22), dp(24), dp(22), dp(10));

        TextView t = new TextView(this);
        t.setText("SETTINGS");
        t.setTextColor(ACCENT);
        t.setTextSize(11);
        t.setLetterSpacing(0.4f);
        t.setTypeface(null, Typeface.BOLD);
        t.setPadding(0, 0, 0, dp(6));
        ll.addView(t);

        TextView s = new TextView(this);
        s.setText("Application preferences");
        s.setTextColor(TEXT_MUTE);
        s.setTextSize(11);
        s.setPadding(0, 0, 0, dp(18));
        ll.addView(s);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(16), dp(14), dp(12), dp(14));
        row.setBackground(Dokunma.box(this, SURFACE, LINE, 14, 1));

        LinearLayout txt = new LinearLayout(this);
        txt.setOrientation(LinearLayout.VERTICAL);
        TextView rt = new TextView(this);
        rt.setText("Haptic feedback");
        rt.setTextColor(TEXT);
        rt.setTextSize(14);
        txt.addView(rt);
        TextView rs = new TextView(this);
        rs.setText("Vibrate on interactions");
        rs.setTextColor(TEXT_MUTE);
        rs.setTextSize(11);
        rs.setPadding(0, dp(4), 0, 0);
        txt.addView(rs);
        row.addView(txt, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        LglSwitch ls = new LglSwitch(this);
        ls.setChecked(Prefs.haptics(this));
        ls.setOnChangeListener((v, c) -> Prefs.setHaptics(this, c));
        row.addView(ls);
        LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        rlp.setMargins(0, 0, 0, dp(12));
        ll.addView(row, rlp);

        Button logs = flatButton("Error logs", ACCENT, ACCENT_SOFT);
        logs.setOnClickListener(v -> {
            String l = DebugLog.read(this, 200);
            if (l.isEmpty()) l = "No logs";
            AlertDialog d = new AlertDialog.Builder(this)
                    .setTitle("Error logs")
                    .setMessage(l)
                    .setPositiveButton("Close", null)
                    .setNeutralButton("Clear", (x, w) -> DebugLog.clear(this))
                    .create();
            Window dw = d.getWindow();
            if (dw != null) dw.setBackgroundDrawable(Dokunma.box(this, SURFACE_HI, LINE, 20, 1));
            d.show();
            d.getButton(DialogInterface.BUTTON_POSITIVE).setTextColor(ACCENT);
            d.getButton(DialogInterface.BUTTON_NEUTRAL).setTextColor(ACCENT);
        });
        LinearLayout.LayoutParams lp1 = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(52));
        lp1.setMargins(0, 0, 0, dp(10));
        ll.addView(logs, lp1);

        Button reset = flatButton("Reset all patches", WARN, 0x22FBBF24);
        reset.setOnClickListener(v -> {
            Yamalar.reset(this);
            Yamalar.loadDefaults(this);
            toast("Reset");
            render();
        });
        ll.addView(reset, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(52)));

        AlertDialog d = new AlertDialog.Builder(this)
                .setView(ll).setPositiveButton("Close", null).create();
        Window w = d.getWindow();
        if (w != null) w.setBackgroundDrawable(Dokunma.box(this, SURFACE_HI, LINE, 22, 1));
        d.show();
        d.getButton(DialogInterface.BUTTON_POSITIVE).setTextColor(ACCENT);
    }

    private Button flatButton(String text, int color, int fill) {
        Button b = new Button(this);
        b.setAllCaps(false);
        b.setText(text);
        b.setTextColor(color);
        b.setTextSize(13);
        b.setTypeface(null, Typeface.BOLD);
        b.setStateListAnimator(null);
        b.setBackground(Dokunma.ripple(this, SURFACE, LINE, fill, 14, 1));
        Dokunma.press(b, this);
        return b;
    }

    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_SHORT).show(); }
}
XEOF

cat > "$PROJE/src/com/valvehack/modmenu/FloatingService.java" <<'XEOF'
package com.valvehack.modmenu;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public class FloatingService extends Service {
    public static volatile boolean active = false;

    private static final int BG          = 0xFF0F0F16;
    private static final int HEADER      = 0xFF0A0A10;
    private static final int SURFACE     = 0xFF16161F;
    private static final int ACCENT      = 0xFFFF2A5C;
    private static final int ACCENT_SOFT = 0x22FF2A5C;
    private static final int TEXT        = 0xFFF5F5F7;
    private static final int TEXT_DIM    = 0xFF8A8A99;
    private static final int TEXT_MUTE   = 0xFF55556A;
    private static final int LINE        = 0xFF23232E;

    private static final int ICON_DP   = 46;
    private static final int MENU_W_DP = 240;
    private static final int ROW_DP    = 46;
    private static final int HEADER_DP = 56;
    private static final int FOOTER_DP = 52;
    private static final long PID_TTL_MS = 1500L;
    private static final long TOGGLE_LOCK_MS = 260L;
    private static final String PKG = Yamalar.AMONG_US;

    private WindowManager wm;
    private View icon;
    private View menu;
    private WindowManager.LayoutParams ilp;
    private boolean menuOpen = false;
    private LinearLayout listArea;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final List<Yamalar.Patch> patches = new ArrayList<>(12);
    private volatile boolean menuAlive = false;
    private int watchedPid = 0;
    private Thread pidWatcher = null;
    private volatile long pidCheckAt = 0L;
    private volatile int pidCached = 0;
    private volatile long lastToggleAt = 0L;

    private File watchLock()       { return new File(getFilesDir(), "watch.pid"); }
    private File noclipModeFile()  { return new File(getFilesDir(), "noclip.mode"); }
    private File chatModeFile()    { return new File(getFilesDir(), "chat.mode"); }
    private File chatMsgsFile()    { return new File(getFilesDir(), "chat.txt"); }
    private File chatItvFile()     { return new File(getFilesDir(), "chat.interval"); }

    private void writeFileSafe(File f, String s) {
        try (FileOutputStream fos = new FileOutputStream(f, false)) {
            fos.write(s.getBytes(StandardCharsets.UTF_8));
            fos.flush();
        } catch (Exception e) { DebugLog.write(this, "file write " + e); }
    }

    @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        active = true;
        setupNotification();
        wm = (WindowManager) getSystemService(WINDOW_SERVICE);
        Yamalar.loadDefaults(this);
        writeFileSafe(noclipModeFile(), Prefs.noclipWanted(this) ? "on" : "off");
        writeFileSafe(chatModeFile(), Prefs.chatWanted(this) ? "on" : "off");
        writeFileSafe(chatMsgsFile(), Prefs.chatMessages(this));
        writeFileSafe(chatItvFile(), String.valueOf(Prefs.chatInterval(this)));
        createIcon();
        syncWatcher();
    }

    @Override public int onStartCommand(Intent i, int f, int s) { return START_STICKY; }

    private void setupNotification() {
        String ch = "valvehack_ch";
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel nc = new NotificationChannel(ch, "ValveHack", NotificationManager.IMPORTANCE_LOW);
            nc.setShowBadge(false);
            NotificationManager nm = getSystemService(NotificationManager.class);
            if (nm != null) nm.createNotificationChannel(nc);
        }
        Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(this, ch) : new Notification.Builder(this);
        b.setContentTitle("ValveHack").setContentText("Menu active")
                .setSmallIcon(android.R.drawable.ic_menu_manage).setOngoing(true);
        startForeground(1001, b.build());
    }

    private int dp(int v) { return (int)(v * getResources().getDisplayMetrics().density); }

    private int winType() {
        return Build.VERSION.SDK_INT >= 26
                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                : WindowManager.LayoutParams.TYPE_PHONE;
    }

    private void createIcon() {
        FrameLayout fl = new FrameLayout(this);

        TextView tv = new TextView(this);
        tv.setText("V");
        tv.setTextColor(Color.WHITE);
        tv.setTextSize(18);
        tv.setGravity(Gravity.CENTER);
        tv.setTypeface(null, Typeface.BOLD);

        GradientDrawable bg = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                new int[]{0xFFFF3D6B, 0xFFC0143E});
        bg.setShape(GradientDrawable.OVAL);
        bg.setStroke(dp(2), 0x55FFFFFF);
        tv.setBackground(bg);
        tv.setElevation(dp(8));
        fl.addView(tv, new FrameLayout.LayoutParams(dp(ICON_DP), dp(ICON_DP), Gravity.CENTER));
        fl.setAlpha(0.92f);

        ilp = new WindowManager.LayoutParams(dp(ICON_DP), dp(ICON_DP),
                winType(), WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT);
        ilp.gravity = Gravity.TOP | Gravity.START;
        ilp.x = dp(12);
        ilp.y = dp(160);

        fl.setOnTouchListener(new View.OnTouchListener() {
            int ix, iy;
            float bx, by;
            boolean drag;
            @Override public boolean onTouch(View v, MotionEvent e) {
                switch (e.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN:
                        ix = ilp.x; iy = ilp.y;
                        bx = e.getRawX(); by = e.getRawY();
                        drag = false;
                        fl.animate().alpha(1f).scaleX(0.9f).scaleY(0.9f).setDuration(80).start();
                        return true;
                    case MotionEvent.ACTION_MOVE: {
                        int dx = (int)(e.getRawX() - bx), dy = (int)(e.getRawY() - by);
                        if (Math.abs(dx) > dp(6) || Math.abs(dy) > dp(6)) drag = true;
                        ilp.x = ix + dx;
                        ilp.y = iy + dy;
                        try { wm.updateViewLayout(icon, ilp); } catch (Exception ignored) {}
                        return true;
                    }
                    case MotionEvent.ACTION_UP:
                        fl.animate().alpha(0.92f).scaleX(1f).scaleY(1f).setDuration(80).start();
                        if (!drag) { Dokunma.haptic(FloatingService.this); toggleMenu(); }
                        return true;
                    case MotionEvent.ACTION_CANCEL:
                        fl.animate().alpha(0.92f).scaleX(1f).scaleY(1f).setDuration(80).start();
                        return true;
                }
                return false;
            }
        });
        icon = fl;
        wm.addView(icon, ilp);
    }

    private void toggleMenu() {
        long now = System.currentTimeMillis();
        if (now - lastToggleAt < TOGGLE_LOCK_MS) return;
        lastToggleAt = now;
        if (menuOpen) closeMenu(); else openMenu();
    }

    private void closeMenu() {
        menuAlive = false;
        if (menu != null) {
            final View m = menu;
            menu = null;
            menuOpen = false;
            m.animate().alpha(0f).scaleX(0.95f).scaleY(0.95f).setDuration(140)
                    .withEndAction(() -> { try { wm.removeView(m); } catch (Exception ignored) {} })
                    .start();
        } else menuOpen = false;
    }

    private void minimize() {
        Dokunma.haptic(this);
        lastToggleAt = System.currentTimeMillis();
        closeMenu();
        if (icon != null) icon.setVisibility(View.VISIBLE);
    }

    private void killService() {
        Dokunma.haptic(this);
        lastToggleAt = System.currentTimeMillis();
        closeMenu();
        ui.postDelayed(this::stopSelf, 180);
    }

    private void openMenu() {
        patches.clear();
        patches.addAll(Yamalar.list(this));
        if (patches.isEmpty()) { toast("No patches"); return; }

        int screenW = getResources().getDisplayMetrics().widthPixels;
        int screenH = getResources().getDisplayMetrics().heightPixels;
        int menuW = Math.min(dp(MENU_W_DP), (int)(screenW * 0.92f));

        int listContentH = patches.size() * dp(ROW_DP) + dp(14);
        int maxListH = (int)(screenH * 0.58f);
        int listH = Math.min(listContentH, maxListH);
        if (listH < dp(70)) listH = dp(70);

        int menuH = dp(HEADER_DP) + 1 + listH + 1 + dp(FOOTER_DP);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackground(Dokunma.box(this, BG, LINE, 20, 1));
        root.setElevation(dp(16));
        root.setClipToOutline(true);

        root.addView(buildMenuHeader(),
                new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(HEADER_DP)));

        View l1 = new View(this); l1.setBackgroundColor(LINE);
        root.addView(l1, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1));

        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(BG);
        sv.setVerticalScrollBarEnabled(false);
        listArea = new LinearLayout(this);
        listArea.setOrientation(LinearLayout.VERTICAL);
        listArea.setPadding(dp(6), dp(6), dp(6), dp(6));
        sv.addView(listArea);
        root.addView(sv, new LinearLayout.LayoutParams(menuW, listH));

        View l2 = new View(this); l2.setBackgroundColor(LINE);
        root.addView(l2, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 1));

        root.addView(buildMenuFooter(),
                new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(FOOTER_DP)));

        int menuX = ilp.x;
        int menuY = ilp.y;
        if (menuX + menuW > screenW) menuX = screenW - menuW;
        if (menuY + menuH > screenH) menuY = screenH - menuH;
        if (menuX < 0) menuX = 0;
        if (menuY < 0) menuY = 0;

        WindowManager.LayoutParams mlp = new WindowManager.LayoutParams(
                menuW, WindowManager.LayoutParams.WRAP_CONTENT, winType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        mlp.gravity = Gravity.TOP | Gravity.START;
        mlp.x = menuX;
        mlp.y = menuY;

        menu = root;
        menuAlive = true;
        wm.addView(menu, mlp);
        menuOpen = true;

        if (icon != null) icon.setVisibility(View.GONE);

        root.setScaleX(0.94f);
        root.setScaleY(0.94f);
        root.setAlpha(0f);
        root.animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(160).start();

        fillList();
    }

    private View buildMenuHeader() {
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        head.setPadding(dp(14), 0, dp(8), 0);
        head.setBackgroundColor(HEADER);

        FrameLayout tile = new FrameLayout(this);
        tile.setBackground(Dokunma.vertical(this, 0xFFFF3D6B, 0xFFC0143E, 12, 0, 0));
        TextView mark = new TextView(this);
        mark.setText("V");
        mark.setTextColor(Color.WHITE);
        mark.setTextSize(15);
        mark.setTypeface(null, Typeface.BOLD);
        mark.setGravity(Gravity.CENTER);
        tile.addView(mark, new FrameLayout.LayoutParams(dp(32), dp(32), Gravity.CENTER));
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(dp(32), dp(32));
        tlp.setMargins(0, 0, dp(10), 0);
        head.addView(tile, tlp);

        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);

        TextView t1 = new TextView(this);
        t1.setText("VALVEHACK");
        t1.setTextColor(TEXT);
        t1.setTextSize(11);
        t1.setTypeface(null, Typeface.BOLD);
        t1.setLetterSpacing(0.22f);
        info.addView(t1);

        TextView t2 = new TextView(this);
        t2.setText(ProcList.name(this, PKG) + "  ·  " + patches.size());
        t2.setTextColor(TEXT_DIM);
        t2.setTextSize(9);
        t2.setSingleLine(true);
        t2.setEllipsize(TextUtils.TruncateAt.END);
        t2.setPadding(0, dp(3), 0, 0);
        info.addView(t2);

        head.addView(info, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        TextView x = new TextView(this);
        x.setText("×");
        x.setTextColor(TEXT_DIM);
        x.setTextSize(20);
        x.setGravity(Gravity.CENTER);
        x.setBackground(Dokunma.ripple(this, 0x00000000, 0, ACCENT_SOFT, 10, 0));
        x.setOnClickListener(v -> minimize());
        Dokunma.fade(x);
        head.addView(x, new LinearLayout.LayoutParams(dp(32), dp(32)));
        return head;
    }

    private View buildMenuFooter() {
        LinearLayout footer = new LinearLayout(this);
        footer.setOrientation(LinearLayout.HORIZONTAL);
        footer.setGravity(Gravity.CENTER_VERTICAL);
        footer.setPadding(dp(10), dp(8), dp(10), dp(8));
        footer.setBackgroundColor(HEADER);

        TextView close = new TextView(this);
        close.setText("CLOSE");
        close.setTextColor(Color.WHITE);
        close.setTextSize(11);
        close.setTypeface(null, Typeface.BOLD);
        close.setLetterSpacing(0.22f);
        close.setGravity(Gravity.CENTER);
        close.setBackground(Dokunma.rippleGrad(this, 0xFFFF3D6B, 0xFFE01F4E, 0, 0x44FFFFFF, 11, 0));
        close.setOnClickListener(v -> killService());
        Dokunma.press(close, this);
        footer.addView(close, new LinearLayout.LayoutParams(0, dp(36), 1f));

        View sp = new View(this);
        footer.addView(sp, new LinearLayout.LayoutParams(dp(8), 0));

        TextView min = new TextView(this);
        min.setText("MINIMIZE");
        min.setTextColor(TEXT);
        min.setTextSize(11);
        min.setTypeface(null, Typeface.BOLD);
        min.setLetterSpacing(0.22f);
        min.setGravity(Gravity.CENTER);
        min.setBackground(Dokunma.ripple(this, SURFACE, LINE, 0x33FFFFFF, 11, 1));
        min.setOnClickListener(v -> minimize());
        Dokunma.press(min, this);
        footer.addView(min, new LinearLayout.LayoutParams(0, dp(36), 1f));
        return footer;
    }

    private void fillList() {
        if (listArea == null) return;
        listArea.removeAllViews();
        for (Yamalar.Patch y : new ArrayList<>(patches)) listArea.addView(buildRow(y));
        refreshStates();
    }

    private View buildRow(final Yamalar.Patch y) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), 0, dp(6), 0);
        row.setBackground(Dokunma.ripple(this, 0x00000000, 0, ACCENT_SOFT, 10, 0));
        row.setLayoutParams(new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(ROW_DP)));
        row.setTag(y.id);

        View bar = new View(this);
        bar.setTag("bar");
        bar.setBackground(Dokunma.box(this, TEXT_MUTE, 0, 4, 0));
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(dp(3), dp(22));
        blp.setMargins(0, 0, dp(10), 0);
        row.addView(bar, blp);

        TextView name = new TextView(this);
        name.setText(y.name);
        name.setTextColor(TEXT);
        name.setTextSize(12);
        name.setSingleLine(true);
        name.setEllipsize(TextUtils.TruncateAt.END);
        row.addView(name, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        LglSwitch sw = new LglSwitch(this);
        sw.setTag("sw");
        boolean swInit;
        if ("noclip".equals(y.type)) swInit = Prefs.noclipWanted(this);
        else if ("chat-spam".equals(y.type)) swInit = Prefs.chatWanted(this);
        else swInit = Prefs.patchOn(this, y.id);
        sw.setChecked(swInit, false);
        sw.setOnChangeListener((v, c) -> toggle(y, v, c));
        row.addView(sw, new LinearLayout.LayoutParams(dp(44), dp(26)));
        return row;
    }

    private void paintRow(String id, boolean on) {
        View row = findRow(id);
        if (row == null) return;
        View bar = row.findViewWithTag("bar");
        if (bar != null) {
            bar.setBackground(Dokunma.box(this, on ? ACCENT : TEXT_MUTE, 0, 4, 0));
        }
    }

    private boolean isSpecial(Yamalar.Patch y) {
        return "noclip".equals(y.type) || "sabotage-all".equals(y.type) || "chat-spam".equals(y.type);
    }

    private boolean isWatcherAlive() {
        File lf = watchLock();
        if (!lf.exists()) return false;
        return System.currentTimeMillis() - lf.lastModified() < 8000;
    }

    private int readWatcherPid() {
        File lf = watchLock();
        if (!lf.exists()) return 0;
        try (java.io.BufferedReader br = new java.io.BufferedReader(new java.io.FileReader(lf))) {
            String line = br.readLine();
            if (line == null) return 0;
            return Integer.parseInt(line.trim());
        } catch (Exception e) { return 0; }
    }

    private synchronized void syncWatcher() {
        boolean need = Prefs.noclipWanted(this) || Prefs.chatWanted(this);
        if (!need) return;
        int pid = findPid(PKG);
        if (pid <= 0) return;
        if (isWatcherAlive() && watchedPid == pid) return;
        stopWatcher();
        startWatcher();
    }

    private synchronized void startWatcher() {
        final int pid = findPid(PKG);
        if (pid <= 0) return;

        int oldPid = readWatcherPid();
        watchLock().delete();

        writeFileSafe(noclipModeFile(), Prefs.noclipWanted(this) ? "on" : "off");
        writeFileSafe(chatModeFile(), Prefs.chatWanted(this) ? "on" : "off");
        writeFileSafe(chatMsgsFile(), Prefs.chatMessages(this));
        writeFileSafe(chatItvFile(), String.valueOf(Prefs.chatInterval(this)));
        watchedPid = pid;

        File b = NativeRunner.prepare(this);
        if (b == null) { DebugLog.write(this, "watch: no binary"); return; }

        StringBuilder cmd = new StringBuilder();
        if (oldPid > 0) {
            cmd.append("kill -9 ").append(oldPid).append(" 2>/dev/null; ");
        }
        cmd.append("nohup ").append(RootShell.sq(b.getAbsolutePath())).append(" watch ")
           .append(pid).append(' ')
           .append(RootShell.sq(noclipModeFile().getAbsolutePath())).append(' ')
           .append(RootShell.sq(chatModeFile().getAbsolutePath())).append(' ')
           .append(RootShell.sq(chatMsgsFile().getAbsolutePath())).append(' ')
           .append(RootShell.sq(chatItvFile().getAbsolutePath())).append(' ')
           .append(RootShell.sq(watchLock().getAbsolutePath()))
           .append(" >/dev/null 2>&1 &");

        RootShell.exec(cmd.toString(), 3000);

        if (pidWatcher == null || !pidWatcher.isAlive()) {
            pidWatcher = new Thread(() -> {
                while (active) {
                    try { Thread.sleep(2000); } catch (InterruptedException e) { break; }
                    if (!active) break;
                    if (!Prefs.noclipWanted(FloatingService.this)
                            && !Prefs.chatWanted(FloatingService.this)) continue;
                    int newPid = findPid(PKG);
                    if (newPid <= 0) continue;
                    if (!isWatcherAlive() || newPid != watchedPid) {
                        syncWatcher();
                    }
                }
            }, "vh-pidwatch");
            pidWatcher.setDaemon(true);
            pidWatcher.start();
        }
    }

    private synchronized void stopWatcher() {
        int wpid = readWatcherPid();
        if (wpid > 0) {
            RootShell.exec("kill -9 " + wpid + " 2>/dev/null", 2000);
        }
        watchLock().delete();
        watchedPid = 0;
    }

    private int findPid(String pkg) {
        long now = System.currentTimeMillis();
        int cached = pidCached;
        if (cached > 0 && now - pidCheckAt < PID_TTL_MS) return cached;
        int result = 0;
        try {
            String out = NativeRunner.shell("pidof -s " + pkg);
            String[] p = out.trim().split("\\s+");
            for (String x : p) {
                try { int v = Integer.parseInt(x); if (v > 1) { result = v; break; } } catch (Exception ignored) {}
            }
        } catch (Exception ignored) {}
        pidCached = result;
        pidCheckAt = now;
        return result;
    }

    private void toggle(final Yamalar.Patch y, final LglSwitch sw, final boolean checked) {
        Dokunma.haptic(this);
        sw.setEnabled(false);
        paintRow(y.id, checked);
        new Thread(() -> {
            final int pid = findPid(PKG);
            if (pid <= 0 && !"noclip".equals(y.type) && !"chat-spam".equals(y.type)) {
                ui.post(() -> {
                    sw.setEnabled(true);
                    sw.setChecked(!checked, false);
                    paintRow(y.id, !checked);
                    toast("Game not running");
                });
                return;
            }
            String result = null;
            if ("noclip".equals(y.type)) {
                Prefs.setNoclipWanted(FloatingService.this, checked);
                writeFileSafe(noclipModeFile(), checked ? "on" : "off");
                syncWatcher();
                result = checked ? "#ON" : "#OFF";
            } else if ("chat-spam".equals(y.type)) {
                Prefs.setChatWanted(FloatingService.this, checked);
                writeFileSafe(chatModeFile(), checked ? "on" : "off");
                writeFileSafe(chatMsgsFile(), Prefs.chatMessages(FloatingService.this));
                writeFileSafe(chatItvFile(), String.valueOf(Prefs.chatInterval(FloatingService.this)));
                syncWatcher();
                result = checked ? "#ON" : "#OFF";
            } else if ("sabotage-all".equals(y.type)) {
                result = NativeRunner.run(this, "sabotage-all", String.valueOf(pid));
            } else {
                String cur;
                if (y.sig != null && !y.sig.isEmpty()) {
                    cur = NativeRunner.run(this, "status-sig",
                            String.valueOf(pid), y.patched, y.original, y.sig);
                    if (cur == null || cur.contains("#?")) {
                        cur = NativeRunner.run(this, "status",
                                String.valueOf(pid), y.library, y.rva, y.patched, y.original);
                    }
                } else {
                    cur = NativeRunner.run(this, "status",
                            String.valueOf(pid), y.library, y.rva, y.patched, y.original);
                }
                String mode = checked ? "on" : "off";
                if (y.sig != null && !y.sig.isEmpty()) {
                    result = NativeRunner.run(this, "patch-sig",
                            String.valueOf(pid), y.patched, y.original, y.sig, mode);
                    if (result == null || result.contains("ERR:")) {
                        String rr = NativeRunner.run(this, "patch",
                                String.valueOf(pid), y.library, y.rva, y.patched, y.original, mode);
                        if (rr != null && (rr.contains("#ON") || rr.contains("#OFF"))) result = rr;
                    }
                } else {
                    result = NativeRunner.run(this, "patch",
                            String.valueOf(pid), y.library, y.rva, y.patched, y.original, mode);
                }
            }
            final String res = result;
            ui.post(() -> {
                sw.setEnabled(true);
                boolean sabotage = "sabotage-all".equals(y.type);
                boolean okOn;
                if (sabotage) okOn = res != null && !res.contains("ERR:");
                else okOn = res != null && res.contains("#ON");
                boolean okOff = res != null && res.contains("#OFF");
                if (isSpecial(y)) {
                    if (!okOn) {
                        sw.setChecked(false, false);
                        paintRow(y.id, false);
                        toast("Action failed");
                    } else {
                        paintRow(y.id, true);
                        if ("noclip".equals(y.type) || "chat-spam".equals(y.type)) {
                            sw.setChecked(true, false);
                        } else {
                            ui.postDelayed(() -> {
                                sw.setChecked(false, false);
                                paintRow(y.id, false);
                            }, 600);
                        }
                    }
                } else {
                    if (!okOn && !okOff) {
                        sw.setChecked(!checked, false);
                        paintRow(y.id, !checked);
                        String em = res == null ? "null" : res.trim().replace("\n", " | ");
                        if (em.length() > 90) em = em.substring(0, 90);
                        toast(em.isEmpty() ? "Patch failed" : em);
                    } else {
                        paintRow(y.id, okOn);
                        Prefs.setPatchOn(FloatingService.this, y.id, okOn);
                    }
                }
            });
        }, "vh-toggle").start();
    }

    private void refreshStates() {
        if (!menuAlive) return;
        final List<Yamalar.Patch> snapshot = new ArrayList<>(patches);
        new Thread(() -> {
            final int pid = findPid(PKG);
            if (pid <= 0) return;
            List<Yamalar.Patch> bytePatches = new ArrayList<>(snapshot.size());
            for (Yamalar.Patch y : snapshot) if (!isSpecial(y)) bytePatches.add(y);
            if (bytePatches.isEmpty()) return;

            int n = bytePatches.size();
            final String[] states = new String[n];
            for (int k = 0; k < n; k++) {
                Yamalar.Patch y = bytePatches.get(k);
                String out = null;
                if (y.sig != null && !y.sig.isEmpty()) {
                    out = NativeRunner.run(FloatingService.this, "status-sig",
                            String.valueOf(pid), y.patched, y.original, y.sig);
                    if (out == null || !out.contains("#ON")) {
                        String rr = NativeRunner.run(FloatingService.this, "status",
                                String.valueOf(pid), y.library, y.rva, y.patched, y.original);
                        if (rr != null && (rr.contains("#ON") || rr.contains("#OFF"))) out = rr;
                    }
                } else {
                    out = NativeRunner.run(FloatingService.this, "status",
                            String.valueOf(pid), y.library, y.rva, y.patched, y.original);
                }
                String t = out == null ? "#?" : out.trim();
                String st;
                if (t.contains("#ON")) st = "#ON";
                else if (t.contains("#OFF")) st = "#OFF";
                else st = "#?";
                states[k] = st;
                DebugLog.write(FloatingService.this, "refresh " + y.name + " -> " + st + " | prefs=" + Prefs.patchOn(FloatingService.this, y.id));
            }
            ui.post(() -> {
                if (!menuAlive) return;
                for (int k = 0; k < bytePatches.size(); k++) {
                    final Yamalar.Patch y = bytePatches.get(k);
                    View row = findRow(y.id);
                    if (row == null) continue;
                    View swV = row.findViewWithTag("sw");
                    if (!(swV instanceof LglSwitch)) continue;
                    LglSwitch sw = (LglSwitch) swV;
                    String st = states[k];
                    if ("#?".equals(st)) continue;
                    boolean prefsOn = Prefs.patchOn(FloatingService.this, y.id);
                    if ("#ON".equals(st)) {
                        Prefs.setPatchOn(FloatingService.this, y.id, true);
                        if (!sw.isChecked()) {
                            sw.setOnChangeListener(null);
                            sw.setChecked(true, false);
                            sw.setOnChangeListener((v, c) -> toggle(y, v, c));
                        }
                        paintRow(y.id, true);
                    } else if ("#OFF".equals(st) && !prefsOn) {
                        if (sw.isChecked()) {
                            sw.setOnChangeListener(null);
                            sw.setChecked(false, false);
                            sw.setOnChangeListener((v, c) -> toggle(y, v, c));
                        }
                        paintRow(y.id, false);
                    }
                }
            });
        }, "vh-refresh").start();
    }

    private View findRow(String id) {
        if (listArea == null) return null;
        for (int i = 0, c = listArea.getChildCount(); i < c; i++) {
            View v = listArea.getChildAt(i);
            if (id.equals(v.getTag())) return v;
        }
        return null;
    }

    private void toast(String s) {
        ui.post(() -> Toast.makeText(this, s, Toast.LENGTH_SHORT).show());
    }

    @Override
    public void onDestroy() {
        active = false;
        menuAlive = false;
        writeFileSafe(noclipModeFile(), "off");
        writeFileSafe(chatModeFile(), "off");
        stopWatcher();
        if (menu != null) { try { wm.removeView(menu); } catch (Exception ignored) {} menu = null; }
        if (icon != null) { try { wm.removeView(icon); } catch (Exception ignored) {} icon = null; }
        super.onDestroy();
    }
}
XEOF

cat > "$PROJE/cpp/valvehack.c" <<'CEOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <sys/uio.h>
#include <sys/syscall.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/stat.h>
#ifndef PTRACE_GETREGSET
#define PTRACE_GETREGSET 0x4204
#endif
#ifndef PTRACE_SETREGSET
#define PTRACE_SETREGSET 0x4205
#endif
#ifndef NT_PRSTATUS
#define NT_PRSTATUS 1
#endif
#ifndef NT_PRFPREG
#define NT_PRFPREG 2
#endif
#ifndef PTRACE_CONT
#define PTRACE_CONT 7
#endif
#define LOG_WATCH "/data/local/tmp/valvehack_watch.log"
#define LOG_CHAT  "/data/local/tmp/valvehack_chat.log"
#define LOG_MAX   262144L
#define RET_OK(o)  ((o) > 0x100000ULL && (o) < 0x800000000000ULL)
#define RET_VALID(r) ((r) > 0ULL && (r) < 0x100000000ULL)
struct arm64_gpr { uint64_t x[31]; uint64_t sp; uint64_t pc; uint64_t pstate; };
struct arm64_fpr { unsigned char data[528]; };
static volatile sig_atomic_t g_stop = 0;
static void on_signal(int sig) { (void)sig; g_stop = 1; }
struct vh_ctx {
    pid_t pid;
    char lib[64];
    uint64_t base;
    uint64_t scratch;
    uint64_t image;
    uint64_t pc_klass;
    uint64_t pc_coll_field;
    uint64_t ship_klass;
    uint64_t mp_set_enabled;
    uint64_t mp_rpc_close_doors;
    uint64_t mp_rpc_send_chat;
    uint64_t m_enabled_offset;
    uint64_t lp_field;
    char map_name[64];
};
static struct vh_ctx C = { 0 };
static uint64_t g_rva_brk              = 0x1ef6b64ULL;
static uint64_t g_rva_domain_get       = 0x1efa1fcULL;
static uint64_t g_rva_domain_asm_open  = 0x1efa200ULL;
static uint64_t g_rva_asm_get_image    = 0x1ef9cccULL;
static uint64_t g_rva_class_from_name  = 0x1ef9d04ULL;
static uint64_t g_rva_class_get_field  = 0x1ef9d24ULL;
static uint64_t g_rva_class_get_method = 0x1ef9d2cULL;
static uint64_t g_rva_class_get_name   = 0x1ef9d30ULL;
static uint64_t g_rva_field_static_get = 0x1efa3e8ULL;
static uint64_t g_rva_field_get_offset = 0x1efa3ccULL;
static uint64_t g_rva_obj_get_class    = 0x1efa5ccULL;
static uint64_t g_rva_thread_attach    = 0x1efa658ULL;
static uint64_t g_rva_string_new_utf16 = 0x1efa644ULL;
static int g_elf_done = 0;
static uint64_t g_rva_gchandle_new        = 0x1efa46cULL;
static uint64_t g_rva_gchandle_get_target = 0x1efa4acULL;
static uint64_t g_rva_gchandle_free       = 0x1efa4f4ULL;
static int g_thread_attached = 0;
#define RVA_BRK              g_rva_brk
#define RVA_DOMAIN_GET       g_rva_domain_get
#define RVA_DOMAIN_ASM_OPEN  g_rva_domain_asm_open
#define RVA_ASM_GET_IMAGE    g_rva_asm_get_image
#define RVA_CLASS_FROM_NAME  g_rva_class_from_name
#define RVA_CLASS_GET_FIELD  g_rva_class_get_field
#define RVA_CLASS_GET_METHOD g_rva_class_get_method
#define RVA_CLASS_GET_NAME   g_rva_class_get_name
#define RVA_FIELD_STATIC_GET g_rva_field_static_get
#define RVA_FIELD_GET_OFFSET g_rva_field_get_offset
#define RVA_OBJ_GET_CLASS    g_rva_obj_get_class
#define RVA_THREAD_ATTACH    g_rva_thread_attach
#define RVA_STRING_NEW_UTF16 g_rva_string_new_utf16

static uint16_t er16(const uint8_t *p){ return (uint16_t)(p[0]|(p[1]<<8)); }
static uint32_t er32(const uint8_t *p){ return (uint32_t)(p[0]|(p[1]<<8)|(p[2]<<16)|((uint32_t)p[3]<<24)); }
static uint64_t er64(const uint8_t *p){ return (uint64_t)er32(p)|((uint64_t)er32(p+4)<<32); }

static int pat_parse(const char *s, uint8_t *b, uint8_t *m, int max) {
    int n = 0;
    const char *p = s;
    while (*p && n < max) {
        while (*p == ' ' || *p == '\t') p++;
        if (!*p) break;
        if (p[0] == '?' && p[1] == '?') { b[n] = 0; m[n] = 0; n++; p += 2; continue; }
        int hi = -1, lo = -1;
        if (p[0] == '?') { p++; }
        else if (p[0] >= '0' && p[0] <= '9') { hi = p[0] - '0'; p++; }
        else if (p[0] >= 'a' && p[0] <= 'f') { hi = p[0] - 'a' + 10; p++; }
        else if (p[0] >= 'A' && p[0] <= 'F') { hi = p[0] - 'A' + 10; p++; }
        else return -1;
        if (!*p) return -1;
        if (p[0] == '?') { p++; }
        else if (p[0] >= '0' && p[0] <= '9') { lo = p[0] - '0'; p++; }
        else if (p[0] >= 'a' && p[0] <= 'f') { lo = p[0] - 'a' + 10; p++; }
        else if (p[0] >= 'A' && p[0] <= 'F') { lo = p[0] - 'A' + 10; p++; }
        else return -1;
        b[n] = (uint8_t)(((hi < 0 ? 0 : hi) << 4) | (lo < 0 ? 0 : lo));
        m[n] = (uint8_t)((hi < 0 ? 0 : 0xF0) | (lo < 0 ? 0 : 0x0F));
        n++;
    }
    return n;
}

static int elf_scan_exec(const uint8_t *data, size_t size,
                         const uint8_t *pat, const uint8_t *msk, int plen,
                         uint64_t *out_first, int *out_count) {
    uint64_t e_phoff = er64(data + 0x20);
    uint16_t e_phentsize = er16(data + 0x36);
    uint16_t e_phnum = er16(data + 0x38);
    int count = 0;
    uint64_t first = 0;
    for (int i = 0; i < e_phnum; i++) {
        const uint8_t *ph = data + e_phoff + (uint64_t)i * e_phentsize;
        if (er32(ph) != 1) continue;
        if (!(er32(ph + 4) & 1)) continue;
        uint64_t poff = er64(ph + 8);
        uint64_t pva  = er64(ph + 16);
        uint64_t pfs  = er64(ph + 32);
        if (poff > size || pfs > size || poff + pfs > size) continue;
        int anchor = -1;
        for (int k = 0; k < plen; k++) { if (msk[k] == 0xFF) { anchor = k; break; } }
        if (anchor < 0) { for (int k = 0; k < plen; k++) { if (msk[k]) { anchor = k; break; } } }
        if (anchor < 0) continue;
        uint8_t anchor_byte = pat[anchor];
        uint64_t j = 0;
        uint64_t end_j = pfs - (uint64_t)plen;
        while (j <= end_j) {
            const uint8_t *hit = (const uint8_t *)memchr(data + poff + j + anchor, anchor_byte, (size_t)(end_j - j + 1));
            if (!hit) break;
            uint64_t jj = (uint64_t)(hit - (data + poff)) - (uint64_t)anchor;
            int match = 1;
            for (int k = 0; k < plen; k++) {
                if (msk[k] && ((data[poff + jj + k] & msk[k]) != (pat[k] & msk[k]))) { match = 0; break; }
            }
            if (match) {
                if (count == 0) first = pva + jj;
                count++;
                if (count > 200) goto done;
            }
            j = jj + 1;
        }
    }
done:
    *out_first = first;
    *out_count = count;
    return count > 0 ? 0 : -1;
}

static uint64_t elf_sym_lookup(const uint8_t *data, uint64_t dynsym_off,
                               uint64_t dynsym_size, uint64_t dynsym_entsize,
                               uint64_t dynstr_off, uint64_t dynstr_size,
                               const char *name) {
    if (dynsym_entsize < 24) dynsym_entsize = 24;
    uint64_t count = dynsym_size / dynsym_entsize;
    for (uint64_t i = 0; i < count; i++) {
        const uint8_t *sym = data + dynsym_off + i * dynsym_entsize;
        uint32_t st_name = er32(sym);
        if (st_name == 0 || st_name >= dynstr_size) continue;
        const char *s = (const char *)(data + dynstr_off + st_name);
        if (!strcmp(s, name)) return er64(sym + 8);
    }
    return 0;
}


static uint64_t fnv1a64(const uint8_t *p, size_t n) {
    uint64_t h = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < n; i++) { h ^= p[i]; h *= 0x100000001b3ULL; }
    return h;
}
static int elf_fingerprint(const uint8_t *buf, size_t sz, unsigned char out[20]) {
    uint64_t h1 = fnv1a64(buf, sz < 4096 ? sz : 4096);
    uint64_t h2 = (sz >= 4096) ? fnv1a64(buf + sz - 4096, 4096) : 0;
    uint64_t h3 = ((uint64_t)sz << 32) ^ (uint64_t)sz;
    uint64_t v[2] = { h1 ^ h3, h2 ^ h3 };
    memcpy(out, v, 16);
    out[16] = (unsigned char)(sz & 0xff);
    out[17] = (unsigned char)((sz >> 8) & 0xff);
    out[18] = (unsigned char)((sz >> 16) & 0xff);
    out[19] = (unsigned char)((sz >> 24) & 0xff);
    return 0;
}

static int elf_fingerprint_file(const char *path, unsigned char out[20]) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return -1; }
    long sz = ftell(f);
    if (sz < 64) { fclose(f); return -1; }
    uint8_t head[4096], tail[4096];
    size_t hlen = (sz < 4096) ? (size_t)sz : 4096;
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return -1; }
    if (fread(head, 1, hlen, f) != hlen) { fclose(f); return -1; }
    if (sz >= 4096) {
        if (fseek(f, sz - 4096, SEEK_SET) != 0) { fclose(f); return -1; }
        if (fread(tail, 1, 4096, f) != 4096) { fclose(f); return -1; }
    } else {
        memcpy(tail, head, hlen);
    }
    fclose(f);
    uint64_t h1 = fnv1a64(head, hlen);
    uint64_t h2 = (sz >= 4096) ? fnv1a64(tail, 4096) : 0;
    uint64_t h3 = ((uint64_t)sz << 32) ^ (uint64_t)sz;
    uint64_t v[2] = { h1 ^ h3, h2 ^ h3 };
    memcpy(out, v, 16);
    out[16] = (unsigned char)(sz & 0xff);
    out[17] = (unsigned char)((sz >> 8) & 0xff);
    out[18] = (unsigned char)((sz >> 16) & 0xff);
    out[19] = (unsigned char)((sz >> 24) & 0xff);
    return 0;
}
#define VH_CACHE_MAGIC 0x43534856u
#define VH_CACHE_VER   4u
#define VH_CACHE_N     16
#define VH_SIG_MAGIC   0x53474856u
#define VH_SIG_VER     1u
#define VH_SIG_MAX     64
static int vh_cache_dir_path(const unsigned char bid[20], const char *prefix,
                             char *out, size_t cap) {
    char hex[41];
    for (int i = 0; i < 20; i++) snprintf(hex + i*2, 3, "%02x", bid[i]);
    hex[40] = 0;
    int n = snprintf(out, cap, "/data/local/tmp/%s_%s.bin", prefix, hex);
    FILE *probe = fopen(out, "ab");
    if (probe) { fclose(probe); return n; }
    n = snprintf(out, cap, "/data/data/com.termux/files/home/.vh_cache/%s_%s.bin", prefix, hex);
    mkdir("/data/data/com.termux/files/home/.vh_cache", 0700);
    return n;
}
static int vh_sig_cache_path(const unsigned char bid[20], char *out, size_t cap) {
    return vh_cache_dir_path(bid, "vh_sigcache", out, cap);
}
static uint64_t vh_hash_sig(const char *s) {
    uint64_t h = 0xcbf29ce484222325ULL;
    while (*s) { h ^= (unsigned char)*s++; h *= 0x100000001b3ULL; }
    return h;
}
static int vh_sig_lookup(const char *path, uint64_t h, uint64_t *out_rva) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    uint32_t magic = 0, ver = 0, cnt = 0;
    if (fread(&magic, 4, 1, f) != 1 || magic != VH_SIG_MAGIC) { fclose(f); return -1; }
    if (fread(&ver, 4, 1, f) != 1 || ver != VH_SIG_VER) { fclose(f); return -1; }
    if (fread(&cnt, 4, 1, f) != 1 || cnt > VH_SIG_MAX) { fclose(f); return -1; }
    for (uint32_t i = 0; i < cnt; i++) {
        uint64_t ch = 0, cr = 0;
        if (fread(&ch, 8, 1, f) != 1 || fread(&cr, 8, 1, f) != 1) { fclose(f); return -1; }
        if (ch == h) { *out_rva = cr; fclose(f); return 0; }
    }
    fclose(f);
    return -1;
}
static int vh_sig_insert(const char *path, uint64_t h, uint64_t rva) {
    uint64_t entries[VH_SIG_MAX][2];
    uint32_t cnt = 0;
    FILE *f = fopen(path, "rb");
    if (f) {
        uint32_t magic = 0, ver = 0;
        if (fread(&magic, 4, 1, f) == 1 && magic == VH_SIG_MAGIC &&
            fread(&ver, 4, 1, f) == 1 && ver == VH_SIG_VER &&
            fread(&cnt, 4, 1, f) == 1 && cnt <= VH_SIG_MAX) {
            for (uint32_t i = 0; i < cnt; i++)
                if (fread(&entries[i][0], 8, 1, f) != 1 ||
                    fread(&entries[i][1], 8, 1, f) != 1) { cnt = 0; break; }
        } else cnt = 0;
        fclose(f);
    }
    for (uint32_t i = 0; i < cnt; i++) if (entries[i][0] == h) return 0;
    if (cnt >= VH_SIG_MAX) return -1;
    entries[cnt][0] = h; entries[cnt][1] = rva; cnt++;
    f = fopen(path, "wb");
    if (!f) return -1;
    uint32_t magic = VH_SIG_MAGIC, ver = VH_SIG_VER;
    fwrite(&magic, 4, 1, f);
    fwrite(&ver, 4, 1, f);
    fwrite(&cnt, 4, 1, f);
    for (uint32_t i = 0; i < cnt; i++) {
        fwrite(&entries[i][0], 8, 1, f);
        fwrite(&entries[i][1], 8, 1, f);
    }
    fclose(f);
    return 0;
}

static int vh_cache_path(const unsigned char bid[20], char *out, size_t cap) {
    return vh_cache_dir_path(bid, "vh_symcache", out, cap);
}
static int vh_cache_load(const char *path, uint64_t out[VH_CACHE_N]) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    uint32_t magic = 0, ver = 0;
    if (fread(&magic, 4, 1, f) != 1 || magic != VH_CACHE_MAGIC) { fclose(f); return -1; }
    if (fread(&ver, 4, 1, f) != 1 || ver != VH_CACHE_VER) { fclose(f); return -1; }
    if (fread(out, 8, VH_CACHE_N, f) != VH_CACHE_N) { fclose(f); return -1; }
    fclose(f);
    return 0;
}
static int vh_cache_save(const char *path, const uint64_t in[VH_CACHE_N]) {
    FILE *f = fopen(path, "wb");
    if (!f) return -1;
    uint32_t magic = VH_CACHE_MAGIC, ver = VH_CACHE_VER;
    fwrite(&magic, 4, 1, f);
    fwrite(&ver, 4, 1, f);
    fwrite(in, 8, VH_CACHE_N, f);
    fclose(f);
    return 0;
}

static int elf_resolve_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (sz <= 64) { fclose(f); return -1; }
    uint8_t *buf = malloc(sz);
    if (!buf) { fclose(f); return -1; }
    if (fread(buf, 1, sz, f) != (size_t)sz) { free(buf); fclose(f); return -1; }
    fclose(f);
    if (memcmp(buf, "\x7f" "ELF", 4) || buf[4] != 2 || buf[5] != 1) { free(buf); return -1; }

    unsigned char bid[20];
    char cpath[256] = { 0 };
    int have_bid = (elf_fingerprint(buf, sz, bid) == 0);
    if (have_bid) {
        vh_cache_path(bid, cpath, sizeof(cpath));
        uint64_t v[VH_CACHE_N];
        if (vh_cache_load(cpath, v) == 0) {
            g_rva_domain_get       = v[0];
            g_rva_domain_asm_open  = v[1];
            g_rva_asm_get_image    = v[2];
            g_rva_class_from_name  = v[3];
            g_rva_class_get_field  = v[4];
            g_rva_class_get_method = v[5];
            g_rva_class_get_name   = v[6];
            g_rva_field_static_get = v[7];
            g_rva_field_get_offset = v[8];
            g_rva_obj_get_class    = v[9];
            g_rva_thread_attach    = v[10];
            g_rva_string_new_utf16 = v[11];
            g_rva_brk              = v[12];
            g_rva_gchandle_new     = v[13];
            g_rva_gchandle_get_target = v[14];
            g_rva_gchandle_free    = v[15];
            fprintf(stderr, "cache: HIT\n");
            free(buf);
            return 0;
        }
    }

    uint64_t e_shoff = er64(buf + 0x28);
    uint16_t e_shentsize = er16(buf + 0x3a);
    uint16_t e_shnum = er16(buf + 0x3c);
    uint16_t e_shstrndx = er16(buf + 0x3e);
    uint64_t shstr_off = 0;
    if (e_shstrndx < e_shnum) {
        const uint8_t *sh = buf + e_shoff + (uint64_t)e_shstrndx * e_shentsize;
        shstr_off = er64(sh + 0x18);
    }
    uint64_t dynsym_off = 0, dynsym_size = 0, dynsym_entsize = 24;
    uint64_t dynstr_off = 0, dynstr_size = 0;
    for (int i = 0; i < e_shnum; i++) {
        const uint8_t *sh = buf + e_shoff + (uint64_t)i * e_shentsize;
        uint32_t name_off = er32(sh);
        uint64_t off = er64(sh + 0x18);
        uint64_t size = er64(sh + 0x20);
        uint64_t entsize = er64(sh + 0x38);
        if (shstr_off + name_off >= (uint64_t)sz) continue;
        const char *nm = (const char *)(buf + shstr_off + name_off);
        if (!strcmp(nm, ".dynsym")) { dynsym_off = off; dynsym_size = size; dynsym_entsize = entsize ? entsize : 24; }
        else if (!strcmp(nm, ".dynstr")) { dynstr_off = off; dynstr_size = size; }
    }
    if (!dynsym_off || !dynstr_off) { free(buf); return -1; }
    const struct { const char *n; uint64_t *o; } map[] = {
        { "il2cpp_domain_get",                  &g_rva_domain_get },
        { "il2cpp_domain_assembly_open",        &g_rva_domain_asm_open },
        { "il2cpp_assembly_get_image",          &g_rva_asm_get_image },
        { "il2cpp_class_from_name",             &g_rva_class_from_name },
        { "il2cpp_class_get_field_from_name",   &g_rva_class_get_field },
        { "il2cpp_class_get_method_from_name",  &g_rva_class_get_method },
        { "il2cpp_class_get_name",              &g_rva_class_get_name },
        { "il2cpp_field_static_get_value",      &g_rva_field_static_get },
        { "il2cpp_field_get_offset",            &g_rva_field_get_offset },
        { "il2cpp_object_get_class",            &g_rva_obj_get_class },
        { "il2cpp_thread_attach",               &g_rva_thread_attach },
        { "il2cpp_string_new_utf16",            &g_rva_string_new_utf16 },
        { "il2cpp_gchandle_new",                &g_rva_gchandle_new },
        { "il2cpp_gchandle_get_target",         &g_rva_gchandle_get_target },
        { "il2cpp_gchandle_free",               &g_rva_gchandle_free },
    };
    for (size_t i = 0; i < sizeof(map)/sizeof(map[0]); i++) {
        uint64_t v = elf_sym_lookup(buf, dynsym_off, dynsym_size, dynsym_entsize,
                                    dynstr_off, dynstr_size, map[i].n);
        if (v) *map[i].o = v;
    }

    {
        const char *BRK_PAT = "20 00 20 d4 e0 03 17 aa ?? ?? ?? 94 f4 03 00 aa";
        uint8_t bpat[32], bmsk[32];
        int blen = pat_parse(BRK_PAT, bpat, bmsk, 32);
        int found = 0;
        if (blen > 0) {
            uint64_t first = 0; int cnt = 0;
            if (elf_scan_exec(buf, sz, bpat, bmsk, blen, &first, &cnt) == 0) {
                g_rva_brk = first;
                fprintf(stderr, "brk: sig x%d rva=0x%llx\n", cnt, (unsigned long long)first);
                found = 1;
            }
        }
        if (!found) {
            static const uint8_t bp[4] = { 0x20, 0x00, 0x20, 0xd4 };
            static const uint8_t bm[4] = { 0xFF, 0xFF, 0xFF, 0xFF };
            uint64_t first = 0; int cnt = 0;
            if (elf_scan_exec(buf, sz, bp, bm, 4, &first, &cnt) == 0) {
                g_rva_brk = first;
                fprintf(stderr, "brk: fallback x%d rva=0x%llx\n", cnt, (unsigned long long)first);
            } else {
                fprintf(stderr, "brk: not found, hardcoded kept\n");
            }
        }
    }

    if (have_bid && cpath[0]) {
        uint64_t v[VH_CACHE_N] = {
            g_rva_domain_get, g_rva_domain_asm_open, g_rva_asm_get_image,
            g_rva_class_from_name, g_rva_class_get_field, g_rva_class_get_method,
            g_rva_class_get_name, g_rva_field_static_get, g_rva_field_get_offset,
            g_rva_obj_get_class, g_rva_thread_attach, g_rva_string_new_utf16,
            g_rva_brk, g_rva_gchandle_new, g_rva_gchandle_get_target, g_rva_gchandle_free
        };
        if (vh_cache_save(cpath, v) == 0)
            fprintf(stderr, "cache: SAVED\n");
    }

    free(buf);
    return 0;
}

static int elf_init_from_pid(pid_t pid) {
    char mp[64];
    snprintf(mp, sizeof(mp), "/proc/%d/maps", pid);
    FILE *f = fopen(mp, "r");
    if (!f) return -1;
    char line[1024];
    char so_path[512] = { 0 };
    while (fgets(line, sizeof(line), f)) {
        if (!strstr(line, "libil2cpp.so")) continue;
        char *p = strchr(line, '/');
        if (!p) continue;
        size_t n = strlen(p);
        if (n > 0 && p[n-1] == 0x0a) p[n-1] = 0;
        strncpy(so_path, p, sizeof(so_path) - 1);
        break;
    }
    fclose(f);
    if (!so_path[0]) return -1;
    return elf_resolve_file(so_path);
}
static long mono_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long)ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}
static void sleep_ms(int ms) {
    if (ms <= 0) return;
    struct timespec ts = { ms / 1000, (long)(ms % 1000) * 1000000L };
    while (nanosleep(&ts, &ts) == -1 && errno == EINTR && !g_stop) { }
}
static void rotate_log(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return;
    if (st.st_size < LOG_MAX) return;
    char tmp[160];
    snprintf(tmp, sizeof(tmp), "%s.old", path);
    rename(path, tmp);
}
static void log_line(const char *path, const char *fmt, ...) {
    rotate_log(path);
    FILE *f = fopen(path, "a");
    if (!f) return;
    time_t now = time(NULL);
    struct tm tm;
    localtime_r(&now, &tm);
    fprintf(f, "[%02d:%02d:%02d] ", tm.tm_hour, tm.tm_min, tm.tm_sec);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(f, fmt, ap);
    va_end(ap);
    fputc('\n', f);
    fclose(f);
}
#define watch_log(...) log_line(LOG_WATCH, __VA_ARGS__)
#define chat_log(...)  log_line(LOG_CHAT,  __VA_ARGS__)
static int hex2bin(const char *s, unsigned char *out, int cap) {
    int L = (int)strlen(s);
    if (L <= 0 || (L & 1) || (L / 2) > cap) return -1;
    int n = L / 2;
    for (int i = 0; i < n; i++) {
        int hi, lo;
        char c = s[2 * i];
        if      (c >= '0' && c <= '9') hi = c - '0';
        else if (c >= 'a' && c <= 'f') hi = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') hi = c - 'A' + 10;
        else return -1;
        c = s[2 * i + 1];
        if      (c >= '0' && c <= '9') lo = c - '0';
        else if (c >= 'a' && c <= 'f') lo = c - 'a' + 10;
        else if (c >= 'A' && c <= 'F') lo = c - 'A' + 10;
        else return -1;
        out[i] = (unsigned char)((hi << 4) | lo);
    }
    return n;
}
static int utf8_to_utf16(const char *s, uint16_t *out, int max) {
    int n = 0;
    const unsigned char *p = (const unsigned char *)s;
    while (*p && n < max - 1) {
        uint32_t cp;
        int extra;
        if      (*p < 0x80)             { cp = *p;        extra = 0; }
        else if ((*p & 0xE0) == 0xC0)   { cp = *p & 0x1F; extra = 1; }
        else if ((*p & 0xF0) == 0xE0)   { cp = *p & 0x0F; extra = 2; }
        else if ((*p & 0xF8) == 0xF0)   { cp = *p & 0x07; extra = 3; }
        else { p++; continue; }
        p++;
        for (int i = 0; i < extra && (*p & 0xC0) == 0x80; i++, p++)
            cp = (cp << 6) | (*p & 0x3F);
        if (cp < 0x10000) {
            out[n++] = (uint16_t)cp;
        } else if (n + 1 < max) {
            cp -= 0x10000;
            out[n++] = (uint16_t)(0xD800 | (cp >> 10));
            out[n++] = (uint16_t)(0xDC00 | (cp & 0x3FF));
        }
    }
    out[n] = 0;
    return n;
}
static int mem_read(pid_t pid, uint64_t addr, void *buf, size_t len) {
    if (!addr || !len) return -1;
    struct iovec li = { buf, len }, ri = { (void *)addr, len };
    if (syscall(SYS_process_vm_readv, pid, &li, 1, &ri, 1, 0) == (ssize_t)len) return 0;
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/mem", pid);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t got = pread(fd, buf, len, (off_t)addr);
    close(fd);
    return got == (ssize_t)len ? 0 : -1;
}
static int mem_write(pid_t pid, uint64_t addr, const void *buf, size_t len) {
    if (!addr || !len) return -1;
    struct iovec li = { (void *)buf, len }, ri = { (void *)addr, len };
    if (syscall(SYS_process_vm_writev, pid, &li, 1, &ri, 1, 0) == (ssize_t)len) return 0;
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/mem", pid);
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t got = pwrite(fd, buf, len, (off_t)addr);
    close(fd);
    return got == (ssize_t)len ? 0 : -1;
}
static void scan_maps(pid_t pid, const char *lib, uint64_t *base, uint64_t *scratch) {
    *base = 0;
    *scratch = 0;
    char path[64];
    snprintf(path, sizeof(path), "/proc/%d/maps", pid);
    FILE *f = fopen(path, "r");
    if (!f) return;
    char line[1024];
    uint64_t rp = 0, rw_end = 0;
    while (fgets(line, sizeof(line), f)) {
        unsigned long lo, hi, fo;
        char perms[8] = { 0 };
        char rest[512] = { 0 };
        if (sscanf(line, "%lx-%lx %7s %lx %511[^\n]", &lo, &hi, perms, &fo, rest) < 5) continue;
        if (!strstr(rest, lib)) continue;
        if (!*base) {
            if (!strcmp(perms, "r--p") && fo == 0) rp = lo;
            else if (!strcmp(perms, "r-xp") && rp) *base = rp;
        }
        if (!strcmp(perms, "rw-p") && hi > rw_end) rw_end = hi;
    }
    fclose(f);
    if (rw_end) *scratch = rw_end - 0x4000ULL;
}
static uint64_t resolve_base(pid_t pid, const char *lib) {
    if (pid == C.pid && C.base && !strcmp(lib, C.lib)) return C.base;
    uint64_t b = 0, s = 0;
    scan_maps(pid, lib, &b, &s);
    if (!b) return 0;
    memset(&C, 0, sizeof(C));
    C.pid = pid;
    strncpy(C.lib, lib, sizeof(C.lib) - 1);
    C.base = b;
    C.scratch = s;
    if (!g_elf_done && !strcmp(lib, "libil2cpp.so")) {
        g_elf_done = 1;
        if (elf_init_from_pid(pid) != 0)
            fprintf(stderr, "elf: init basarisiz, hardcoded RVA aktif\n");
    }
    if (s) {
        unsigned char probe[32];
        if (mem_read(pid, s, probe, sizeof(probe)) == 0) {
            int clean = 1;
            for (size_t i = 0; i < sizeof(probe); i++) if (probe[i]) { clean = 0; break; }
            if (!clean) {
                fprintf(stderr, "scratch: not clean, shifting -0x2000\n");
                C.scratch = s - 0x2000ULL;
            }
        }
    }
    return b;
}
static int get_gpr(pid_t pid, struct arm64_gpr *r) {
    struct iovec iov = { r, sizeof(*r) };
    return (int)syscall(SYS_ptrace, PTRACE_GETREGSET, pid, (void *)(long)NT_PRSTATUS, &iov);
}
static int set_gpr(pid_t pid, struct arm64_gpr *r) {
    struct iovec iov = { r, sizeof(*r) };
    return (int)syscall(SYS_ptrace, PTRACE_SETREGSET, pid, (void *)(long)NT_PRSTATUS, &iov);
}
static int get_fpr(pid_t pid, struct arm64_fpr *r) {
    struct iovec iov = { r, sizeof(*r) };
    return (int)syscall(SYS_ptrace, PTRACE_GETREGSET, pid, (void *)(long)NT_PRFPREG, &iov);
}
static int set_fpr(pid_t pid, struct arm64_fpr *r) {
    struct iovec iov = { r, sizeof(*r) };
    return (int)syscall(SYS_ptrace, PTRACE_SETREGSET, pid, (void *)(long)NT_PRFPREG, &iov);
}
static uint64_t remote_call(pid_t pid, uint64_t fn, uint64_t brk,
                            uint64_t a0, uint64_t a1, uint64_t a2,
                            uint64_t a3, uint64_t a4, uint64_t a5) {
    if (!fn || (fn & 3)) return 0;
    struct arm64_gpr saved, work;
    struct arm64_fpr fsaved;
    int have_fpr = (get_fpr(pid, &fsaved) == 0);
    if (get_gpr(pid, &saved) < 0) return 0;
    work = saved;
    work.x[0] = a0; work.x[1] = a1; work.x[2] = a2;
    work.x[3] = a3; work.x[4] = a4; work.x[5] = a5;
    work.x[6] = 0; work.x[7] = 0;
    work.x[30] = brk;
    work.pc = fn & ~3ULL;
    work.sp &= ~0xFULL;
    if (set_gpr(pid, &work) < 0) return 0;
    if (syscall(SYS_ptrace, PTRACE_CONT, pid, 0, 0) < 0) {
        set_gpr(pid, &saved);
        if (have_fpr) set_fpr(pid, &fsaved);
        return 0;
    }
    int status = 0, ok = 0;
    for (int guard = 0; guard < 2000; guard++) {
        pid_t w = waitpid(pid, &status, 0);
        if (w < 0) {
            if (errno == EINTR && !g_stop) continue;
            break;
        }
        if (!WIFSTOPPED(status)) break;
        int sig = WSTOPSIG(status);
        if (sig == SIGTRAP) { ok = 1; break; }
        if (sig == SIGBUS || sig == SIGSEGV || sig == SIGILL || sig == SIGFPE) {
            struct arm64_gpr bad;
            if (get_gpr(pid, &bad) == 0) { bad.pc = brk; set_gpr(pid, &bad); }
            syscall(SYS_ptrace, PTRACE_CONT, pid, 0, 0);
            for (int g2 = 0; g2 < 200; g2++) {
                w = waitpid(pid, &status, 0);
                if (w < 0) break;
                if (WIFSTOPPED(status)) {
                    if (WSTOPSIG(status) == SIGTRAP) ok = 1;
                    break;
                }
                break;
            }
            break;
        }
        break;
    }
    uint64_t ret = 0;
    if (ok) {
        struct arm64_gpr after;
        if (get_gpr(pid, &after) == 0) ret = after.x[0] & 0x00FFFFFFFFFFFFFFULL;
    }
    set_gpr(pid, &saved);
    if (have_fpr) set_fpr(pid, &fsaved);
    return ret;
}
static void write_str(pid_t pid, uint64_t addr, const char *s) {
    mem_write(pid, addr, s, strlen(s) + 1);
}
static int tracer_pid(pid_t pid) {
    char path[64], buf[256];
    snprintf(path, sizeof(path), "/proc/%d/status", pid);
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    int t = -1;
    while (fgets(buf, sizeof(buf), f)) {
        if (sscanf(buf, "TracerPid:\t%d", &t) == 1) break;
    }
    fclose(f);
    return t;
}
#ifndef PTRACE_SEIZE
#define PTRACE_SEIZE 0x4206
#endif
#ifndef PTRACE_INTERRUPT
#define PTRACE_INTERRUPT 0x4207
#endif
static int ptrace_attach(pid_t pid) {
    int t = tracer_pid(pid);
    if (t > 0 && t != getpid()) return -1;
    if (ptrace(PTRACE_SEIZE, pid, 0, 0) == 0) {
        if (ptrace(PTRACE_INTERRUPT, pid, 0, 0) == 0) {
            int status;
            for (int g = 0; g < 200; g++) {
                pid_t w = waitpid(pid, &status, 0);
                if (w < 0 && errno == EINTR) continue;
                if (w < 0) break;
                if (WIFSTOPPED(status)) return 0;
                if (WIFEXITED(status) || WIFSIGNALED(status)) break;
            }
        }
        ptrace(PTRACE_DETACH, pid, 0, 0);
    }
    if (ptrace(PTRACE_ATTACH, pid, 0, 0) < 0) return -1;
    int status;
    if (waitpid(pid, &status, 0) < 0) {
        ptrace(PTRACE_DETACH, pid, 0, 0);
        return -1;
    }
    return 0;
}
static void ptrace_detach(pid_t pid) {
    ptrace(PTRACE_DETACH, pid, 0, 0);
}
static uint64_t resolve_image(pid_t pid, uint64_t base) {
    if (C.image) return C.image;
    uint64_t brk = base + RVA_BRK;
    uint64_t dom = remote_call(pid, base + RVA_DOMAIN_GET, brk, 0, 0, 0, 0, 0, 0);
    if (!dom) return 0;
    remote_call(pid, base + RVA_THREAD_ATTACH, brk, dom, 0, 0, 0, 0, 0);
    write_str(pid, C.scratch, "Assembly-CSharp");
    uint64_t asm_ = remote_call(pid, base + RVA_DOMAIN_ASM_OPEN, brk, dom, C.scratch, 0, 0, 0, 0);
    if (!asm_) return 0;
    C.image = remote_call(pid, base + RVA_ASM_GET_IMAGE, brk, asm_, 0, 0, 0, 0, 0);
    return C.image;
}
static uint64_t find_klass(pid_t pid, uint64_t base, const char *name) {
    if (!C.image) return 0;
    uint64_t brk = base + RVA_BRK;
    write_str(pid, C.scratch + 0x10, "");
    write_str(pid, C.scratch + 0x20, name);
    return remote_call(pid, base + RVA_CLASS_FROM_NAME, brk, C.image,
                       C.scratch + 0x10, C.scratch + 0x20, 0, 0, 0);
}
static uint64_t field_offset(pid_t pid, uint64_t base, uint64_t klass, const char *name) {
    uint64_t brk = base + RVA_BRK;
    write_str(pid, C.scratch + 0x40, name);
    uint64_t fld = remote_call(pid, base + RVA_CLASS_GET_FIELD, brk, klass,
                               C.scratch + 0x40, 0, 0, 0, 0);
    if (!fld) return 0;
    return remote_call(pid, base + RVA_FIELD_GET_OFFSET, brk, fld, 0, 0, 0, 0, 0);
}
static uint64_t method_ptr(pid_t pid, uint64_t base, uint64_t klass, const char *name, int argc) {
    uint64_t brk = base + RVA_BRK;
    write_str(pid, C.scratch + 0x40, name);
    uint64_t mi = remote_call(pid, base + RVA_CLASS_GET_METHOD, brk, klass,
                              C.scratch + 0x40, (uint64_t)argc, 0, 0, 0);
    if (!mi) return 0;
    uint64_t ptr = 0;
    mem_read(pid, mi, &ptr, 8);
    return ptr;
}
static int warm_cache(pid_t pid, uint64_t base) {
    if (C.pc_klass && C.ship_klass && C.m_enabled_offset) return 0;
    if (!resolve_image(pid, base)) return -1;
    if (!C.pc_klass) {
        C.pc_klass = find_klass(pid, base, "PlayerControl");
        if (C.pc_klass) C.pc_coll_field = field_offset(pid, base, C.pc_klass, "Collider");
    }
    if (!C.lp_field && C.pc_klass) {
        write_str(pid, C.scratch + 0x40, "LocalPlayer");
        C.lp_field = remote_call(pid, base + RVA_CLASS_GET_FIELD, base + RVA_BRK,
                                 C.pc_klass, C.scratch + 0x40, 0, 0, 0, 0);
        watch_log("LocalPlayer field=%llx", (unsigned long long)C.lp_field);
    }
    if (!C.m_enabled_offset) {
        uint64_t beh = find_klass(pid, base, "Behaviour");
        if (beh) {
            C.m_enabled_offset = field_offset(pid, base, beh, "m_Enabled");
            if (!C.m_enabled_offset) C.m_enabled_offset = field_offset(pid, base, beh, "enabled");
            if (!C.m_enabled_offset) C.m_enabled_offset = field_offset(pid, base, beh, "<Enabled>k__BackingField");
        }
        watch_log("Behaviour.m_Enabled offset=0x%llx", (unsigned long long)C.m_enabled_offset);
    }
    if (!C.ship_klass) {
        C.ship_klass = find_klass(pid, base, "ShipStatus");
        if (C.ship_klass) {
            C.mp_rpc_close_doors = method_ptr(pid, base, C.ship_klass, "RpcCloseDoorsOfType", 1);
            uint64_t np = remote_call(pid, base + RVA_CLASS_GET_NAME, base + RVA_BRK,
                                      C.ship_klass, 0, 0, 0, 0, 0);
            if (np) mem_read(pid, np, C.map_name, 63);
        }
    }
    return 0;
}
static int read_lp(pid_t pid, uint64_t base, uint64_t *out) {
    if (!C.lp_field) return -1;
    uint64_t zero = 0;
    mem_write(pid, C.scratch + 0x80, &zero, 8);
    remote_call(pid, base + RVA_FIELD_STATIC_GET, base + RVA_BRK,
                C.lp_field, C.scratch + 0x80, 0, 0, 0, 0);
    return mem_read(pid, C.scratch + 0x80, out, 8);
}
static int static_value(pid_t pid, uint64_t base, uint64_t klass, const char *name, uint64_t *out) {
    uint64_t brk = base + RVA_BRK;
    uint64_t zero = 0;
    write_str(pid, C.scratch + 0x40, name);
    uint64_t fld = remote_call(pid, base + RVA_CLASS_GET_FIELD, brk, klass,
                               C.scratch + 0x40, 0, 0, 0, 0);
    if (!fld) return -1;
    mem_write(pid, C.scratch + 0x80, &zero, 8);
    remote_call(pid, base + RVA_FIELD_STATIC_GET, brk, fld, C.scratch + 0x80, 0, 0, 0, 0);
    return mem_read(pid, C.scratch + 0x80, out, 8);
}
static int enum_value(pid_t pid, uint64_t base, uint64_t klass, const char *name, int32_t *out) {
    uint64_t brk = base + RVA_BRK;
    uint64_t zero = 0;
    write_str(pid, C.scratch + 0x40, name);
    uint64_t fld = remote_call(pid, base + RVA_CLASS_GET_FIELD, brk, klass,
                               C.scratch + 0x40, 0, 0, 0, 0);
    if (!fld) return -1;
    mem_write(pid, C.scratch + 0x80, &zero, 8);
    remote_call(pid, base + RVA_FIELD_STATIC_GET, brk, fld, C.scratch + 0x80, 0, 0, 0, 0);
    return mem_read(pid, C.scratch + 0x80, out, 4);
}
static int live_unity_object(pid_t pid, uint64_t obj) {
    if (!RET_OK(obj)) return 0;
    uint64_t cached = 0;
    if (mem_read(pid, obj + 0x10, &cached, 8) != 0) return 0;
    return RET_OK(cached);
}
static int apply_noclip(pid_t pid, uint64_t base, uint64_t lp, int want_disabled) {
    if (!live_unity_object(pid, lp)) return 0;
    if (!C.pc_coll_field) return 0;
    uint64_t coll = 0;
    if (mem_read(pid, lp + C.pc_coll_field, &coll, 8) != 0) return 0;
    if (!live_unity_object(pid, coll)) return 0;
    unsigned char want = want_disabled ? 0 : 1;
    if (C.m_enabled_offset) {
        unsigned char cur = want;
        if (mem_read(pid, coll + C.m_enabled_offset, &cur, 1) != 0) return 0;
        if (cur == want) return 0;
        for (int i = 0; i < 2; i++) {
            mem_write(pid, coll + C.m_enabled_offset, &want, 1);
            if (i == 0) {
                struct timespec ts = { 0, 80000000L };
                nanosleep(&ts, NULL);
            }
        }
        return 1;
    }
    if (!C.mp_set_enabled) {
        uint64_t pc_klass = remote_call(pid, base + RVA_OBJ_GET_CLASS, base + RVA_BRK, lp, 0, 0, 0, 0, 0);
        if (!pc_klass) return 0;
        C.mp_set_enabled = method_ptr(pid, base, pc_klass, "set_enabled", 1);
    }
    if (!C.mp_set_enabled) return 0;
    remote_call(pid, C.mp_set_enabled, base + RVA_BRK, coll, (uint64_t)want, 0, 0, 0, 0);
    return 1;
}
static int cmd_noclip(pid_t pid, int enabled) {
    if (ptrace_attach(pid) != 0) { fprintf(stderr, "ERR:attach\n"); return 0; }
    uint64_t base = resolve_base(pid, "libil2cpp.so");
    if (!base) { ptrace_detach(pid); fprintf(stderr, "ERR:base\n"); return 0; }
    if (warm_cache(pid, base) < 0 || !C.pc_klass) {
        ptrace_detach(pid); fprintf(stderr, "ERR:warm\n"); return 0;
    }
    uint64_t lp = 0;
    if (static_value(pid, base, C.pc_klass, "LocalPlayer", &lp) != 0 || !RET_OK(lp)) {
        ptrace_detach(pid);
        fprintf(stderr, "ERR:lp\n");
        return 0;
    }
    int ok = apply_noclip(pid, base, lp, enabled ? 1 : 0);
    ptrace_detach(pid);
    printf(enabled ? "#ON\n" : "#OFF\n");
    return ok || 1;
}
static void close_all_doors(pid_t pid, uint64_t base) {
    if (!C.mp_rpc_close_doors || !C.ship_klass) return;
    uint64_t ship = 0;
    if (static_value(pid, base, C.ship_klass, "Instance", &ship) != 0 || !RET_OK(ship)) return;
    int rooms[32];
    int n = 0;
    if (strstr(C.map_name, "SkeldShipStatus")) {
        int r[] = { 1, 2, 4, 7, 10, 11, 13 }; n = 7;
        for (int i = 0; i < n; i++) rooms[i] = r[i];
    } else if (strstr(C.map_name, "PolusShipStatus")) {
        int r[] = { 1, 3, 4, 5, 6, 7, 8, 11, 13, 14 }; n = 10;
        for (int i = 0; i < n; i++) rooms[i] = r[i];
    } else if (strstr(C.map_name, "AirshipStatus")) {
        int r[] = { 1, 2, 4, 5, 6, 7, 8, 9, 10, 13 }; n = 10;
        for (int i = 0; i < n; i++) rooms[i] = r[i];
    } else if (strstr(C.map_name, "FungleShipStatus")) {
        int r[] = { 1, 2, 3, 5, 6, 7, 8, 9, 11, 13 }; n = 10;
        for (int i = 0; i < n; i++) rooms[i] = r[i];
    } else {
        for (int i = 0; i <= 30; i++) rooms[n++] = i;
    }
    uint64_t brk = base + RVA_BRK;
    for (int i = 0; i < n; i++)
        remote_call(pid, C.mp_rpc_close_doors, brk, ship, (uint64_t)rooms[i], 0, 0, 0, 0);
}
static int cmd_sabotage(pid_t pid) {
    if (ptrace_attach(pid) != 0) { fprintf(stderr, "ERR:attach\n"); return 0; }
    uint64_t base = resolve_base(pid, "libil2cpp.so");
    if (!base) { ptrace_detach(pid); fprintf(stderr, "ERR:base\n"); return 0; }
    if (warm_cache(pid, base) < 0 || !C.ship_klass) {
        ptrace_detach(pid); fprintf(stderr, "ERR:warm\n"); return 0;
    }
    uint64_t stk = find_klass(pid, base, "SystemTypes");
    if (!stk) { ptrace_detach(pid); fprintf(stderr, "ERR:st\n"); return 0; }
    int32_t v_re = -1, v_el = -1, v_ls = -1, v_cm = -1;
    enum_value(pid, base, stk, "Reactor", &v_re);
    enum_value(pid, base, stk, "Electrical", &v_el);
    enum_value(pid, base, stk, "LifeSupp", &v_ls);
    if (v_ls < 0) enum_value(pid, base, stk, "LifeSupport", &v_ls);
    enum_value(pid, base, stk, "Comms", &v_cm);
    if (v_cm < 0) enum_value(pid, base, stk, "Communication", &v_cm);
    struct { int sys; int amt; } list[4];
    int n = 0, ok = 0;
    if (v_re >= 0) { list[n].sys = v_re; list[n].amt = 128; n++; }
    if (v_el >= 0) { list[n].sys = v_el; list[n].amt = 4;   n++; }
    if (v_ls >= 0) { list[n].sys = v_ls; list[n].amt = 128; n++; }
    if (v_cm >= 0) { list[n].sys = v_cm; list[n].amt = 128; n++; }
    uint64_t brk = base + RVA_BRK;
    for (int i = 0; i < n; i++) {
        uint64_t ship = 0;
        if (static_value(pid, base, C.ship_klass, "Instance", &ship) != 0 || !RET_OK(ship)) continue;
        uint64_t k = remote_call(pid, base + RVA_OBJ_GET_CLASS, brk, ship, 0, 0, 0, 0, 0);
        if (!k) continue;
        uint64_t mp = method_ptr(pid, base, k, "RpcUpdateSystem", 2);
        if (!mp) mp = method_ptr(pid, base, k, "UpdateSystem", 2);
        if (!mp) continue;
        remote_call(pid, mp, brk, ship, (uint64_t)list[i].sys, (uint64_t)list[i].amt, 0, 0, 0);
        ok++;
    }
    close_all_doors(pid, base);
    ptrace_detach(pid);
    printf("SABOTAGE ALL: %d/%d\n", ok, n);
    return ok > 0;
}
static int read_mode(const char *path) {
    if (!path) return 0;
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    char buf[8] = { 0 };
    int on = 0;
    if (fgets(buf, sizeof(buf), f)) on = (strncmp(buf, "on", 2) == 0);
    fclose(f);
    return on;
}
static int load_chat_msgs(const char *path, char msgs[][256], int max) {
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    int n = 0;
    while (n < max && fgets(msgs[n], 256, f)) {
        int L = (int)strlen(msgs[n]);
        while (L > 0 && (msgs[n][L - 1] == 0x0A || msgs[n][L - 1] == 0x0D)) msgs[n][--L] = 0;
        if (L > 0) n++;
    }
    fclose(f);
    return n;
}
static int load_chat_interval(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return 3;
    int v = 3;
    if (fscanf(f, "%d", &v) != 1) v = 3;
    fclose(f);
    if (v < 1) v = 1;
    if (v > 60) v = 60;
    return v;
}
static uint64_t send_chat_once(pid_t pid, uint64_t base, uint64_t lp,
                                const char *msg, int *out_wlen) {
    uint64_t brk = base + RVA_BRK;
    if (!g_thread_attached) {
        uint64_t dom = remote_call(pid, base + RVA_DOMAIN_GET, brk, 0, 0, 0, 0, 0, 0);
        if (dom) {
            remote_call(pid, base + RVA_THREAD_ATTACH, brk, dom, 0, 0, 0, 0, 0);
            g_thread_attached = 1;
        }
    }
    uint16_t wbuf[128];
    int wlen = utf8_to_utf16(msg, wbuf, 128);
    if (out_wlen) *out_wlen = wlen;
    if (wlen <= 0) return 0;
    if (wlen > 100) { wbuf[100] = 0; wlen = 100; }
    uint64_t sp = C.scratch + 0x300;
    if (mem_write(pid, sp, wbuf, (size_t)(wlen + 1) * 2) != 0) return 0;
    uint64_t str = remote_call(pid, base + RVA_STRING_NEW_UTF16, brk, sp,
                                (uint64_t)wlen, 0, 0, 0, 0);
    if (!str) return 0;
    uint64_t gh = 0;
    if (g_rva_gchandle_new)
        gh = remote_call(pid, base + g_rva_gchandle_new, brk, str, 1, 0, 0, 0, 0);
    uint64_t ret = 0;
    if (!C.mp_rpc_send_chat)
        C.mp_rpc_send_chat = method_ptr(pid, base, C.pc_klass, "RpcSendChat", 1);
    if (C.mp_rpc_send_chat)
        ret = remote_call(pid, C.mp_rpc_send_chat, brk, lp, str, 0, 0, 0, 0);
    if (gh && g_rva_gchandle_free)
        remote_call(pid, base + g_rva_gchandle_free, brk, gh, 0, 0, 0, 0, 0);
    return ret;
}
static int other_watcher_alive(const char *lock_path) {
    if (!lock_path) return 0;
    FILE *f = fopen(lock_path, "r");
    if (!f) return 0;
    int pid = 0;
    if (fscanf(f, "%d", &pid) != 1) { fclose(f); return 0; }
    fclose(f);
    if (pid <= 1 || pid == (int)getpid()) return 0;
    if (kill(pid, 0) != 0) return 0;
    return 1;
}
static void touch_lock(const char *lock_path) {
    if (!lock_path) return;
    FILE *f = fopen(lock_path, "w");
    if (f) { fprintf(f, "%d\n", (int)getpid()); fclose(f); }
}
static int cmd_watch(pid_t pid, const char *noclip_mode, const char *chat_mode,
                     const char *chat_msgs_path, const char *chat_itv_path,
                     const char *lock_path) {
    if (other_watcher_alive(lock_path)) {
        fprintf(stderr, "ERR:already_running\n");
        return 0;
    }
    touch_lock(lock_path);
    watch_log("=== start pid=%d ===", (int)pid);
    int chat_idx = 0;
    long chat_next_ms = 0;
    int was_chat_on = 0;
    int was_noclip_on = 0;
    char chat_msgs[16][256];
    int chat_n = 0;
    long chat_mtime = 0;
    long touch_next = 0;
    long dbg_next = 0;
    while (!g_stop) {
        if (kill(pid, 0) != 0) { watch_log("pid dead, exit"); break; }
        long tnow = mono_ms();
        if (tnow >= touch_next) { touch_lock(lock_path); touch_next = tnow + 2000; }
        int noclip_on = read_mode(noclip_mode);
        int chat_on = read_mode(chat_mode);
        int dbg = (tnow >= dbg_next);
        if (dbg) dbg_next = tnow + 5000;
        if (!noclip_on && !chat_on) {
            if (was_noclip_on) {
                if (ptrace_attach(pid) == 0) {
                    uint64_t base = resolve_base(pid, "libil2cpp.so");
                    if (base && warm_cache(pid, base) == 0 && C.pc_klass) {
                        uint64_t lp = 0;
                        read_lp(pid, base, &lp);
                        if (live_unity_object(pid, lp)) {
                            int r = apply_noclip(pid, base, lp, 0);
                            watch_log("noclip restored before idle r=%d", r);
                        }
                    }
                    ptrace_detach(pid);
                }
                was_noclip_on = 0;
            }
            was_chat_on = 0;
            sleep_ms(500);
            continue;
        }
        if (noclip_on) was_noclip_on = 1;
        if (ptrace_attach(pid) != 0) { sleep_ms(500); continue; }
        uint64_t base = resolve_base(pid, "libil2cpp.so");
        int did_work = 0;
        if (base && warm_cache(pid, base) == 0 && C.pc_klass) {
            uint64_t lp = 0;
            read_lp(pid, base, &lp);
            if (dbg) watch_log("loop noclip=%d chat=%d lp=%llx", noclip_on, chat_on, (unsigned long long)lp);
            if (live_unity_object(pid, lp)) {
                int want_disabled = noclip_on ? 1 : 0;
                int changed = apply_noclip(pid, base, lp, want_disabled);
                if (changed) {
                    watch_log("noclip %s lp=%llx", noclip_on ? "ON" : "OFF", (unsigned long long)lp);
                    did_work = 1;
                }
                if (chat_on) {
                    if (!was_chat_on) { chat_next_ms = 0; chat_idx = 0; }
                    struct stat cst;
                    if (stat(chat_msgs_path, &cst) == 0 && cst.st_mtime != chat_mtime) {
                        chat_n = load_chat_msgs(chat_msgs_path, chat_msgs, 16);
                        chat_mtime = cst.st_mtime;
                        if (chat_n > 0 && chat_idx >= chat_n) chat_idx = 0;
                    }
                    if (chat_n == 0) {
                        chat_n = load_chat_msgs(chat_msgs_path, chat_msgs, 16);
                        if (stat(chat_msgs_path, &cst) == 0) chat_mtime = cst.st_mtime;
                    }
                    long now_ms = mono_ms();
                    if (now_ms >= chat_next_ms && chat_n > 0) {
                        int interval = load_chat_interval(chat_itv_path);
                        int wlen = 0;
                        uint64_t ret = send_chat_once(pid, base, lp, chat_msgs[chat_idx], &wlen);
                        int ok = RET_VALID(ret);
                        chat_log("idx=%d wlen=%d ret=%llu ok=%d", chat_idx, wlen, (unsigned long long)ret, ok);
                        chat_idx = (chat_idx + 1) % chat_n;
                        chat_next_ms = mono_ms() + (long)interval * 1000L;
                        if (ok) did_work = 1;
                    }
                }
            }
        }
        ptrace_detach(pid);
        was_chat_on = chat_on;
        if (chat_on) {
            long now_ms = mono_ms();
            long remain = chat_next_ms - now_ms;
            if (remain > 30 && remain < 300) sleep_ms((int)remain);
            else sleep_ms(220);
        } else {
            sleep_ms(did_work ? 280 : 450);
        }
    }
    if (lock_path) unlink(lock_path);
    return 0;
}
static int cmd_chat_test(pid_t pid, const char *chat_msgs_path) {
    if (ptrace_attach(pid) != 0) { fprintf(stderr, "ERR:attach\n"); return 0; }
    uint64_t base = resolve_base(pid, "libil2cpp.so");
    if (!base) { ptrace_detach(pid); fprintf(stderr, "ERR:base\n"); return 0; }
    if (warm_cache(pid, base) < 0 || !C.pc_klass) {
        ptrace_detach(pid); fprintf(stderr, "ERR:warm\n"); return 0;
    }
    uint64_t lp = 0;
    if (static_value(pid, base, C.pc_klass, "LocalPlayer", &lp) != 0 || !RET_OK(lp)) {
        ptrace_detach(pid); fprintf(stderr, "ERR:lp\n"); return 0;
    }
    char msgs[16][256];
    int n = load_chat_msgs(chat_msgs_path, msgs, 16);
    printf("messages loaded: %d\n", n);
    for (int i = 0; i < n; i++) {
        int wlen = 0;
        uint64_t ret = send_chat_once(pid, base, lp, msgs[i], &wlen);
        chat_log("test idx=%d wlen=%d ret=%llu", i, wlen, (unsigned long long)ret);
        printf("  [%d] wlen=%d ret=%llu msg=\"%.40s\"\n", i, wlen, (unsigned long long)ret, msgs[i]);
        if (i + 1 < n) sleep_ms(3000);
    }
    ptrace_detach(pid);
    return 1;
}

static int find_so_path(pid_t pid, char *out, size_t cap) {
    char mp[64];
    snprintf(mp, sizeof(mp), "/proc/%d/maps", pid);
    FILE *f = fopen(mp, "r");
    if (!f) return -1;
    char line[1024];
    out[0] = 0;
    while (fgets(line, sizeof(line), f)) {
        if (!strstr(line, "libil2cpp.so")) continue;
        char *q = strchr(line, '/');
        if (!q) continue;
        size_t n = strlen(q);
        if (n > 0 && q[n-1] == '\n') q[n-1] = 0;
        strncpy(out, q, cap - 1);
        break;
    }
    fclose(f);
    return out[0] ? 0 : -1;
}

static int sig_find_rva(pid_t pid, const char *sig_str, uint64_t *out_rva, int *out_olen) {
    uint8_t spat[1024], smsk[1024];
    int slen = pat_parse(sig_str, spat, smsk, 1024);
    if (slen <= 0) return -1;
    int wc_start = -1, wc_end = -1;
    for (int i = 0; i < slen; i++) {
        if (!smsk[i]) { if (wc_start < 0) wc_start = i; wc_end = i; }
    }
    if (wc_start < 0) return -1;
    char so_path[512];
    if (find_so_path(pid, so_path, sizeof(so_path)) != 0) return -1;

    uint64_t sig_h = vh_hash_sig(sig_str);
    unsigned char fp[20];
    char scpath[256] = { 0 };
    int have_fp = 0;
    if (elf_fingerprint_file(so_path, fp) == 0) {
        have_fp = 1;
        vh_sig_cache_path(fp, scpath, sizeof(scpath));
    }
    if (have_fp) {
        uint64_t cached_rva = 0;
        if (vh_sig_lookup(scpath, sig_h, &cached_rva) == 0) {
            *out_rva = cached_rva + (uint64_t)wc_start;
            if (out_olen) *out_olen = wc_end - wc_start + 1;
            fprintf(stderr, "sigcache: HIT\n");
            return 0;
        }
    }

    FILE *sf = fopen(so_path, "rb");
    if (!sf) return -1;
    fseek(sf, 0, SEEK_END); long sz = ftell(sf); fseek(sf, 0, SEEK_SET);
    if (sz <= 64) { fclose(sf); return -1; }
    uint8_t *buf = malloc(sz);
    if (!buf) { fclose(sf); return -1; }
    if (fread(buf, 1, sz, sf) != (size_t)sz) { free(buf); fclose(sf); return -1; }
    fclose(sf);
    uint64_t first = 0; int cnt = 0;
    elf_scan_exec(buf, sz, spat, smsk, slen, &first, &cnt);
    free(buf);
    if (cnt == 0) return -1;
    uint64_t patched_at = first + (uint64_t)wc_start;
    if (have_fp) {
        if (vh_sig_insert(scpath, sig_h, first) == 0)
            fprintf(stderr, "sigcache: SAVED rva=0x%llx\n", (unsigned long long)patched_at);
    }
    *out_rva = patched_at;
    if (out_olen) *out_olen = wc_end - wc_start + 1;
    return 0;
}

static int cmd_patch_sig(pid_t pid, const char *patched_hex, const char *original_hex, const char *sig_str, int force) {
    uint8_t patched[256], original[256];
    int plen = hex2bin(patched_hex, patched, sizeof(patched));
    int olen = hex2bin(original_hex, original, sizeof(original));
    if (plen <= 0 || olen != plen) { fprintf(stderr, "ERR:hex\n"); return 1; }
    uint64_t rva = 0;
    if (sig_find_rva(pid, sig_str, &rva, NULL) != 0) { fprintf(stderr, "ERR:nosig\n"); return 1; }
    if (ptrace_attach(pid) != 0) { fprintf(stderr, "ERR:attach\n"); return 1; }
    uint64_t base = resolve_base(pid, "libil2cpp.so");
    if (!base) { ptrace_detach(pid); fprintf(stderr, "ERR:base\n"); return 1; }
    uint64_t addr = base + rva;
    if (force == 1) {
        if (mem_write(pid, addr, patched, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
        __builtin___clear_cache((char *)addr, (char *)(addr + plen));
        ptrace_detach(pid); printf("#ON\n"); return 0;
    }
    if (force == 2) {
        if (mem_write(pid, addr, original, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
        __builtin___clear_cache((char *)addr, (char *)(addr + plen));
        ptrace_detach(pid); printf("#OFF\n"); return 0;
    }
    unsigned char cur[256];
    if (mem_read(pid, addr, cur, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:read\n"); return 1; }
    if (!memcmp(cur, original, plen)) {
        if (mem_write(pid, addr, patched, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
        __builtin___clear_cache((char *)addr, (char *)(addr + plen));
        ptrace_detach(pid); printf("#ON\n"); return 0;
    }
    if (!memcmp(cur, patched, plen)) {
        if (mem_write(pid, addr, original, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
        __builtin___clear_cache((char *)addr, (char *)(addr + plen));
        ptrace_detach(pid); printf("#OFF\n"); return 0;
    }
    ptrace_detach(pid);
    fprintf(stderr, "ERR:nomatch rva=0x%llx cur=%02x%02x%02x%02x\n",
            (unsigned long long)rva, cur[0], cur[1], cur[2], cur[3]);
    return 1;
}

static int cmd_status_sig(pid_t pid, const char *patched_hex, const char *original_hex, const char *sig_str) {
    uint8_t patched[256], original[256];
    int plen = hex2bin(patched_hex, patched, sizeof(patched));
    int olen = hex2bin(original_hex, original, sizeof(original));
    if (plen <= 0 || olen != plen) { printf("#?\n"); return 0; }
    uint64_t rva = 0;
    if (sig_find_rva(pid, sig_str, &rva, NULL) != 0) { printf("#?\n"); return 0; }
    uint64_t base = resolve_base(pid, "libil2cpp.so");
    if (!base) { printf("#?\n"); return 0; }
    uint64_t addr = base + rva;
    unsigned char cur[256];
    if (mem_read(pid, addr, cur, plen) != 0) { printf("#?\n"); return 0; }
    if (!memcmp(cur, original, plen)) printf("#OFF\n");
    else if (!memcmp(cur, patched, plen)) printf("#ON\n");
    else printf("#?\n");
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "ERR:usage\n"); return 2; }
    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);
    signal(SIGHUP, on_signal);
    signal(SIGPIPE, SIG_IGN);
    if (!strcmp(argv[1], "patch-sig") && (argc == 6 || argc == 7)) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { fprintf(stderr, "ERR:pid\n"); return 1; }
        int force = 0;
        if (argc == 7) {
            if (!strcmp(argv[6], "on")) force = 1;
            else if (!strcmp(argv[6], "off")) force = 2;
        }
        return cmd_patch_sig(pid, argv[3], argv[4], argv[5], force);
    }
    if (!strcmp(argv[1], "status-sig") && argc == 6) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { printf("#?\n"); return 0; }
        return cmd_status_sig(pid, argv[3], argv[4], argv[5]);
    }
    if (!strcmp(argv[1], "patch") && (argc == 7 || argc == 8)) {
        pid_t pid = (pid_t)atoi(argv[2]);
        const char *lib = argv[3];
        uint64_t rva = strtoull(argv[4], NULL, 16);
        unsigned char patched[128], original[128];
        int plen = hex2bin(argv[5], patched, sizeof(patched));
        int olen = hex2bin(argv[6], original, sizeof(original));
        if (plen <= 0 || olen != plen) { fprintf(stderr, "ERR:hex\n"); return 1; }
        int force = 0;
        if (argc == 8) {
            if (!strcmp(argv[7], "on")) force = 1;
            else if (!strcmp(argv[7], "off")) force = 2;
        }
        if (ptrace_attach(pid) != 0) { fprintf(stderr, "ERR:attach\n"); return 1; }
        uint64_t base = resolve_base(pid, lib);
        if (!base) { ptrace_detach(pid); fprintf(stderr, "ERR:base\n"); return 1; }
        uint64_t addr = base + rva;
        if (force == 1) {
            if (mem_write(pid, addr, patched, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
            __builtin___clear_cache((char *)addr, (char *)(addr + plen));
            ptrace_detach(pid);
            printf("#ON\n"); return 0;
        }
        if (force == 2) {
            if (mem_write(pid, addr, original, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
            __builtin___clear_cache((char *)addr, (char *)(addr + plen));
            ptrace_detach(pid);
            printf("#OFF\n"); return 0;
        }
        unsigned char cur[128];
        if (mem_read(pid, addr, cur, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:read\n"); return 1; }
        if (!memcmp(cur, original, plen)) {
            if (mem_write(pid, addr, patched, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
            __builtin___clear_cache((char *)addr, (char *)(addr + plen));
            ptrace_detach(pid);
            printf("#ON\n"); return 0;
        }
        if (!memcmp(cur, patched, plen)) {
            if (mem_write(pid, addr, original, plen) != 0) { ptrace_detach(pid); fprintf(stderr, "ERR:write\n"); return 1; }
            __builtin___clear_cache((char *)addr, (char *)(addr + plen));
            ptrace_detach(pid);
            printf("#OFF\n"); return 0;
        }
        ptrace_detach(pid);
        fprintf(stderr, "ERR:nomatch\n"); return 1;
    }
    if (!strcmp(argv[1], "status") && argc == 7) {
        pid_t pid = (pid_t)atoi(argv[2]);
        const char *lib = argv[3];
        uint64_t rva = strtoull(argv[4], NULL, 16);
        unsigned char patched[128], original[128];
        int plen = hex2bin(argv[5], patched, sizeof(patched));
        int olen = hex2bin(argv[6], original, sizeof(original));
        if (plen <= 0 || olen != plen) { printf("#?\n"); return 0; }
        if (ptrace_attach(pid) != 0) { printf("#?\n"); return 0; }
        uint64_t base = resolve_base(pid, lib);
        if (!base) { ptrace_detach(pid); printf("#?\n"); return 0; }
        uint64_t addr = base + rva;
        unsigned char cur[128];
        if (mem_read(pid, addr, cur, plen) != 0) { ptrace_detach(pid); printf("#?\n"); return 0; }
        int r_ = 0;
        if (!memcmp(cur, original, plen)) r_ = 1;
        else if (!memcmp(cur, patched, plen)) r_ = 2;
        ptrace_detach(pid);
        if (r_ == 1) printf("#OFF\n");
        else if (r_ == 2) printf("#ON\n");
        else printf("#?\n");
        return 0;
    }
    if (!strcmp(argv[1], "status-multi") && argc >= 4) {
        pid_t pid = (pid_t)atoi(argv[2]);
        int count = atoi(argv[3]);
        if (pid <= 0 || count <= 0 || count > 128) return 1;
        if (argc != 4 + count * 4) {
            for (int i = 0; i < count; i++) printf("#?\n");
            return 1;
        }
        for (int i = 0; i < count; i++) {
            const char *lib = argv[4 + i * 4];
            uint64_t rva = strtoull(argv[4 + i * 4 + 1], NULL, 16);
            unsigned char patched[128], original[128];
            int plen = hex2bin(argv[4 + i * 4 + 2], patched, sizeof(patched));
            int olen = hex2bin(argv[4 + i * 4 + 3], original, sizeof(original));
            if (plen <= 0 || olen != plen) { printf("#?\n"); continue; }
            uint64_t base = resolve_base(pid, lib);
            if (!base) { printf("#?\n"); continue; }
            uint64_t addr = base + rva;
            unsigned char cur[128];
            if (mem_read(pid, addr, cur, plen) != 0) { printf("#?\n"); continue; }
            if (!memcmp(cur, original, plen)) printf("#OFF\n");
            else if (!memcmp(cur, patched, plen)) printf("#ON\n");
            else printf("#?\n");
        }
        return 0;
    }
    if (!strcmp(argv[1], "noclip") && argc == 4) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { fprintf(stderr, "ERR:pid\n"); return 1; }
        return cmd_noclip(pid, atoi(argv[3])) ? 0 : 1;
    }
    if (!strcmp(argv[1], "sabotage-all") && argc == 3) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { fprintf(stderr, "ERR:pid\n"); return 1; }
        return cmd_sabotage(pid) ? 0 : 1;
    }
    if (!strcmp(argv[1], "watch") && argc == 8) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { fprintf(stderr, "ERR:pid\n"); return 1; }
        return cmd_watch(pid, argv[3], argv[4], argv[5], argv[6], argv[7]);
    }
    if (!strcmp(argv[1], "chat-test") && argc == 4) {
        pid_t pid = (pid_t)atoi(argv[2]);
        if (pid <= 0) { fprintf(stderr, "ERR:pid\n"); return 1; }
        return cmd_chat_test(pid, argv[3]) ? 0 : 1;
    }
    fprintf(stderr, "ERR:cmd\n");
    return 2;
}
CEOF

ok "Project written"

yaz "Native"
rm -f "$PROJE/assets/valvehack"
CCLOG="$HOME/valvehack-cc.log"
if "$CLANG" -O2 -fPIE -pie -o "$PROJE/assets/valvehack" "$PROJE/cpp/valvehack.c" > "$CCLOG" 2>&1; then ok "native"
elif "$CLANG" --target=aarch64-linux-android26 -O2 -fPIE -pie -o "$PROJE/assets/valvehack" "$PROJE/cpp/valvehack.c" > "$CCLOG" 2>&1; then ok "native (a26)"
elif "$CLANG" --target=aarch64-linux-android24 -O2 -fPIE -pie -o "$PROJE/assets/valvehack" "$PROJE/cpp/valvehack.c" > "$CCLOG" 2>&1; then ok "native (a24)"
else tail -30 "$CCLOG"; hata "native"; fi
[ -s "$PROJE/assets/valvehack" ] || hata "binary missing"
chmod 755 "$PROJE/assets/valvehack"
ok "$(stat -c %s "$PROJE/assets/valvehack") bytes"

yaz "Resources"
COMP="$PROJE/build/compiled"
rm -rf "$COMP"; mkdir -p "$COMP"
"$AAPT2" compile --dir "$PROJE/res" -o "$COMP/res.zip" 2>&1 | tail -5
[ -f "$COMP/res.zip" ] || hata "aapt2 compile"
ok "Done"

yaz "Link"
LINKED="$PROJE/build/unsigned.apk"
GEN="$PROJE/build/gen"
rm -rf "$GEN"; mkdir -p "$GEN"
"$AAPT2" link -o "$LINKED" -I "$ANDROID_JAR" -A "$PROJE/assets" \
    --manifest "$PROJE/AndroidManifest.xml" --java "$GEN" \
    --min-sdk-version 26 --target-sdk-version 34 \
    --version-code "$KOD" --version-name "$SURUM" \
    --auto-add-overlay "$COMP/res.zip" 2>&1 | tail -8
[ -f "$LINKED" ] || hata "link"
[ -f "$GEN/com/valvehack/modmenu/R.java" ] || hata "R.java"
ok "Done"

yaz "Java"
CLS="$PROJE/build/classes"
rm -rf "$CLS"; mkdir -p "$CLS"
LIST="$PROJE/build/jl.txt"
{ find "$PROJE/src" -name "*.java"; echo "$GEN/com/valvehack/modmenu/R.java"; } > "$LIST"
"$JAVAC" --release 8 -classpath "$ANDROID_JAR" -d "$CLS" -encoding UTF-8 @"$LIST" 2>&1 | tail -20
[ -f "$CLS/com/valvehack/modmenu/FloatingService.class" ] || hata "FS compile failed"
[ -f "$CLS/com/valvehack/modmenu/MainActivity.class" ] || hata "MA compile failed"
[ -f "$CLS/com/valvehack/modmenu/LglSwitch.class" ] || hata "LS compile failed"
[ -f "$CLS/com/valvehack/modmenu/RootShell.class" ] || hata "RS compile failed"
ok "Done"

yaz "DEX"
DEX="$PROJE/build/dex"
rm -rf "$DEX"; mkdir -p "$DEX"
CL="$PROJE/build/cl.txt"
find "$CLS" -name "*.class" > "$CL"
"$JAVA" -cp "$R8JAR" com.android.tools.r8.D8 --min-api 26 \
    --output "$DEX" --lib "$ANDROID_JAR" @"$CL" 2>&1 | tail -10
[ -f "$DEX/classes.dex" ] || hata "dex"
SIZE=$(stat -c %s "$DEX/classes.dex")
[ "$SIZE" -gt 10000 ] || hata "dex too small: $SIZE"
ok "$SIZE bytes"

yaz "Package"
PKG_APK="$PROJE/build/pkg.apk"
cp "$LINKED" "$PKG_APK"
(cd "$DEX" && zip -q "$PKG_APK" classes.dex)
ok "Done"

yaz "Keystore"
KS="$HOME/.android/debug.keystore"
mkdir -p "$HOME/.android"
[ -f "$KS" ] || keytool -genkey -v -keystore "$KS" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
[ -f "$KS" ] || hata "ks"
ok "Done"

yaz "Sign"
FINAL="$PROJE/build/ValveHack-${SURUM}.apk"
rm -f "$FINAL"
"$JAVA" -jar "$APKSIGNER" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey --v1-signing-enabled true --v2-signing-enabled true \
    --out "$FINAL" "$PKG_APK" 2>&1 | tail -6
[ -f "$FINAL" ] || hata "sign"
ok "$(stat -c %s "$FINAL") bytes"

yaz "Copy"
TARGET="/sdcard/Download/ValveHack-${SURUM}.apk"
if cp "$FINAL" "$TARGET" 2>/dev/null; then ok "$TARGET"
else TARGET="$HOME/ValveHack-${SURUM}.apk"; cp "$FINAL" "$TARGET"; ok "$TARGET"; fi

printf "\n%s╔══════════════════════════════════════════════╗%s\n" "$P" "$R"
printf "%s║  ✓ ValveHack v%s — AMONG US EDITION%s\n" "$P" "$SURUM" "$R"
printf "%s╚══════════════════════════════════════════════╝%s\n\n" "$P" "$R"
printf "  APK     : %s\n" "$TARGET"
printf "  Package : %s\n\n" "$PKG"
printf "  %sChanges in v5.0.0:%s\n" "$C" "$R"
printf "  • Persistent root shell (single su prompt per session)\n"
printf "  • No more repeated Superuser toasts on idle\n"
printf "  • Watcher spawned via nohup — no double su on start\n"
printf "  • Root check moved off UI thread\n"
printf "  • BuildID/fingerprint cache: vh_symcache_<id>.bin\n"
printf "  • ELF resolver: ONCE per .so (g_elf_done guard)\n"
printf "  • PTRACE_SEIZE + INTERRUPT — sessiz attach\n"
printf "  • il2cpp_gchandle ile chat string pin (GC crash fix)\n"
printf "  • Watcher: 500ms idle / 450ms aktif, geri çekilme\n"
printf "  • Scratch: kullanımdan önce zero-verify\n"
printf "  • Byte patch imzalari da cache: vh_sigcache_<id>.bin\n"
printf "  • Fingerprint: 8KB head+tail (200ms -> 10ms HIT)\n"
printf "  %sTarget:%s\n" "$C" "$R"
printf "  • com.innersloth.spacemafia (Among Us)\n\n"
printf "  %sPatches:%s\n" "$C" "$R"
printf "  • No Clip       : Collider m_Enabled\n"
printf "  • Sabotage All  : 4 systems + map-aware doors\n"
printf "  • Chat Spam     : editable messages + interval\n"
printf "  • Plus 7 byte patches\n\n"
