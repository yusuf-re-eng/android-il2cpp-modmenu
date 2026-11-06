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
