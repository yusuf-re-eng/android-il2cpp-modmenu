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
