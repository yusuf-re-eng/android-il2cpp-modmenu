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
