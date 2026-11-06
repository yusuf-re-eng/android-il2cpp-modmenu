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
