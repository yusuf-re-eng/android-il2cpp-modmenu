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
