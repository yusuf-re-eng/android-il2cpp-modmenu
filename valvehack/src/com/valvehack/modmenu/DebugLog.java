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
