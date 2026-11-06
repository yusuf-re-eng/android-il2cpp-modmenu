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
