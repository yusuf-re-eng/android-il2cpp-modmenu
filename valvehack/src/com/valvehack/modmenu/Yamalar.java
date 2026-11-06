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
