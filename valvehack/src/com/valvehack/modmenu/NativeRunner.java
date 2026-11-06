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
