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
