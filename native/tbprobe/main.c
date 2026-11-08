/* UCI subset over pinned Fathom. Built as C11 on Linux and C++14 with MSVC. */
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tbprobe.h"
#ifdef _WIN32
#include <windows.h>
#include <wchar.h>
#else
#include <unistd.h>
#endif

typedef struct {
    char squares[64];
    unsigned clock, ep, count;
    bool white;
} Position;

typedef struct {
    char uci[6];
    unsigned wdl, dtz;
} Move;

static const char *table_path = "";
static const char *wdl_names[] = {"loss", "blessed-loss", "draw", "cursed-win", "win"};

static bool own_directory(void) {
#ifdef _WIN32
    wchar_t path[32768];
    DWORD n = GetModuleFileNameW(NULL, path, 32768);
    if (!n || n >= 32768) return false;
    wchar_t *slash = wcsrchr(path, L'\\');
    if (!slash) return false;
    *slash = L'\0';
    return SetCurrentDirectoryW(path) != 0;
#else
    char path[4096];
    ssize_t n = readlink("/proc/self/exe", path, sizeof(path) - 1);
    if (n <= 0 || (size_t)n >= sizeof(path) - 1) return false;
    path[n] = '\0';
    char *slash = strrchr(path, '/');
    if (!slash) return false;
    *slash = '\0';
    return chdir(path) == 0;
#endif
}

static bool counter(const char *s, unsigned *out, bool positive) {
    if (!*s) return false;
    for (const char *p = s; *p; ++p) if (!isdigit((unsigned char)*p)) return false;
    errno = 0;
    unsigned long n = strtoul(s, NULL, 10);
    if (errno || n > UINT_MAX || (positive && n == 0)) return false;
    *out = (unsigned)n;
    return true;
}

static const char *parse_fen(const char *fen, Position *p) {
    char placement[80], side[3], castling[8], ep[4], clock[16], number[16];
    int used = 0;
    unsigned fullmove;
    memset(p, 0, sizeof(*p));
    if (sscanf(fen, "%79s %2s %7s %3s %15s %15s %n", placement, side, castling,
               ep, clock, number, &used) != 6 || used == 0 || fen[used] != '\0')
        return "invalid FEN";
    if (strcmp(side, "w") && strcmp(side, "b")) return "invalid FEN side";
    if (strcmp(castling, "-")) return "castling rights are not probeable";
    if (!counter(clock, &p->clock, false) || !counter(number, &fullmove, true))
        return "invalid FEN counters";
    /* The game is already drawn at 100; never let Fathom's uint8_t clock wrap. */
    if (p->clock > 100) p->clock = 100;
    p->white = !strcmp(side, "w");
    int rank = 7, file = 0, wk = 0, bk = 0;
    for (const char *c = placement; *c; ++c) {
        if (*c == '/') {
            if (file != 8 || rank == 0) return "invalid FEN ranks";
            --rank; file = 0;
        } else if (*c >= '1' && *c <= '8') {
            file += *c - '0';
            if (file > 8) return "invalid FEN rank width";
        } else {
            if (!strchr("KQRBNPkqrbnp", *c) || file >= 8) return "invalid FEN piece";
            if ((*c == 'P' || *c == 'p') && (rank == 0 || rank == 7)) return "invalid FEN pawn";
            p->squares[rank * 8 + file++] = *c;
            ++p->count;
            wk += *c == 'K'; bk += *c == 'k';
        }
    }
    if (rank != 0 || file != 8 || wk != 1 || bk != 1) return "invalid FEN board";
    if (strcmp(ep, "-")) {
        if (strlen(ep) != 2 || ep[0] < 'a' || ep[0] > 'h' || ep[1] != (p->white ? '6' : '3'))
            return "invalid FEN en passant";
        p->ep = (unsigned)((ep[1] - '1') * 8 + ep[0] - 'a');
        unsigned pawn = p->white ? p->ep - 8 : p->ep + 8;
        if (p->squares[p->ep] || p->squares[pawn] != (p->white ? 'p' : 'P'))
            return "invalid FEN en passant pawn";
    }
    return NULL;
}

static unsigned root(const Position *p, unsigned *moves, bool zero_clock) {
    uint64_t white = 0, black = 0, types[6] = {0};
    for (unsigned i = 0; i < 64; ++i) {
        char c = p->squares[i];
        if (!c) continue;
        uint64_t bit = UINT64_C(1) << i;
        if (isupper((unsigned char)c)) white |= bit; else black |= bit;
        const char *kinds = "kqrbnp";
        const char *kind = strchr(kinds, tolower((unsigned char)c));
        types[kind - kinds] |= bit;
    }
    return tb_probe_root(white, black, types[0], types[1], types[2], types[3], types[4],
                         types[5], zero_clock ? 0 : p->clock, 0, p->ep, p->white, moves);
}

static Position child_position(const Position *p, unsigned move) {
    Position child = *p;
    unsigned from = TB_GET_FROM(move), to = TB_GET_TO(move), promotion = TB_GET_PROMOTES(move);
    char piece = p->squares[from];
    bool pawn = piece == 'P' || piece == 'p';
    bool capture = p->squares[to] != 0 || TB_GET_EP(move);
    child.squares[from] = 0;
    child.squares[to] = promotion ? (p->white ? " QRBN"[promotion] : " qrbn"[promotion]) : piece;
    if (TB_GET_EP(move)) child.squares[p->white ? to - 8 : to + 8] = 0;
    child.clock = pawn || capture ? 0 : p->clock + 1;
    if (child.clock > 100) child.clock = 100;
    child.ep = pawn && abs((int)to - (int)from) == 16 ? (from + to) / 2 : 0;
    child.count -= capture;
    child.white = !p->white;
    return child;
}

/* Check both filename orientations; bare kings have no files. This also checks
 * child DTZ files that Fathom's zeroing-move optimization only reads as WDL. */
static bool material_files(const Position *p) {
    if (p->count == 2) return true;
    char sides[2][8] = {{0}}, material[18], path[16384];
    for (unsigned side = 0; side < 2; ++side) {
        unsigned n = 0;
        for (const char *kind = "KQRBNP"; *kind; ++kind)
            for (unsigned sq = 0; sq < 64; ++sq)
                if (p->squares[sq] == (side ? tolower(*kind) : *kind)) sides[side][n++] = *kind;
    }
    for (unsigned flip = 0; flip < 2; ++flip) {
        snprintf(material, sizeof(material), "%sv%s", sides[flip], sides[1 - flip]);
        bool found = true;
        for (const char *ext = "wz"; *ext; ++ext) {
            int n = snprintf(path, sizeof(path), "%s/%s.rtb%c", table_path, material, *ext);
            if (n < 0 || (size_t)n >= sizeof(path)) return false;
            FILE *file = fopen(path, "rb");
            if (!file) { found = false; break; }
            bool valid = fseek(file, 0, SEEK_END) == 0;
            long size = valid ? ftell(file) : -1;
            fclose(file);
            if (size < 16 || size % 64 != 16) { found = false; break; }
        }
        if (found) return true;
    }
    return false;
}

static int compare_moves(const void *a, const void *b) {
    const Move *x = (const Move *)a, *y = (const Move *)b;
    if (x->wdl != y->wdl) return x->wdl > y->wdl ? -1 : 1;
    if (x->dtz != y->dtz) {
        if (x->wdl > TB_DRAW) return x->dtz < y->dtz ? -1 : 1;
        if (x->wdl < TB_DRAW) return x->dtz > y->dtz ? -1 : 1;
    }
    return strcmp(x->uci, y->uci);
}

static void fail(const char *reason) {
    printf("info string tberror %s\nbestmove (none)\n", reason);
}

static void probe(const char *fen) {
    Position pos;
    const char *error = parse_fen(fen, &pos);
    if (error) { fail(error); return; }
    if (pos.count > TB_LARGEST) { fail("more pieces than loaded tables cover"); return; }
    if (!material_files(&pos)) { fail("missing or unreadable position table"); return; }
    unsigned results[TB_MAX_MOVES], baseline[TB_MAX_MOVES];
    unsigned answer = root(&pos, results, false);
    if (answer == TB_RESULT_FAILED) { fail("Fathom root probe failed"); return; }
    if (answer == TB_RESULT_CHECKMATE || answer == TB_RESULT_STALEMATE) {
        puts("bestmove (none)"); return;
    }
    if (root(&pos, baseline, true) == TB_RESULT_FAILED) { fail("Fathom clock-zero probe failed"); return; }
    Move moves[TB_MAX_MOVES];
    unsigned count = 0;
    for (; count < TB_MAX_MOVES && results[count] != TB_RESULT_FAILED; ++count) {
        unsigned raw = results[count], base = baseline[count];
        if (base == TB_RESULT_FAILED || (raw & ~TB_RESULT_WDL_MASK & ~TB_RESULT_DTZ_MASK) !=
                (base & ~TB_RESULT_WDL_MASK & ~TB_RESULT_DTZ_MASK)) {
            fail("Fathom move sets differ"); return;
        }
        Position child = child_position(&pos, raw);
        if (!material_files(&child)) { fail("missing or unreadable child table"); return; }
        if (root(&child, NULL, false) == TB_RESULT_FAILED) { fail("Fathom child probe failed"); return; }
        Move *move = &moves[count];
        unsigned from = TB_GET_FROM(raw), to = TB_GET_TO(raw), promotion = TB_GET_PROMOTES(raw);
        move->uci[0] = 'a' + from % 8; move->uci[1] = '1' + from / 8;
        move->uci[2] = 'a' + to % 8; move->uci[3] = '1' + to / 8;
        move->uci[4] = promotion ? " qrbn"[promotion] : '\0'; move->uci[5] = '\0';
        move->wdl = TB_GET_WDL(raw);
        move->dtz = TB_GET_DTZ(raw);
        /* DTZ50 encodes an intrinsic cursed/blessed result with a +100 offset.
         * A clock-induced curse has no offset: distinguish with clock-zero WDL. */
        if (TB_GET_WDL(base) == TB_CURSED_WIN || TB_GET_WDL(base) == TB_BLESSED_LOSS)
            move->dtz -= 100;
    }
    if (!count || count == TB_MAX_MOVES) { fail("invalid Fathom move count"); return; }
    qsort(moves, count, sizeof(*moves), compare_moves);
    for (unsigned i = 0; i < count; ++i)
        printf("info string tbmove %s %s %u\n", moves[i].uci, wdl_names[moves[i].wdl], moves[i].dtz);
    printf("bestmove %s\n", moves[0].uci);
}

int main(void) {
    if (!own_directory()) { puts("error could not change to helper directory"); return 1; }
    char line[16384], fen[512] = "", path[16384] = "";
    while (fgets(line, sizeof(line), stdin)) {
        size_t n = strlen(line);
        if (n && line[n - 1] == '\n') line[--n] = '\0';
        if (n && line[n - 1] == '\r') line[--n] = '\0';
        if (!strcmp(line, "uci"))
            puts("id name P-Chess tbprobe (Fathom " FATHOM_COMMIT ")\nuciok");
        else if (!strncmp(line, "setoption name SyzygyPath value ", 32)) {
            strcpy(path, line + 32); table_path = path;
            if (!tb_init(path) || !TB_LARGEST) printf("error tablebase files not found in %s\n", path);
        } else if (!strcmp(line, "isready")) puts("readyok");
        else if (!strncmp(line, "position fen ", 13)) {
            if (strlen(line + 13) >= sizeof(fen)) fen[0] = '\0';
            else strcpy(fen, line + 13);
        } else if (!strcmp(line, "go")) probe(fen);
        else if (!strcmp(line, "quit")) break;
        fflush(stdout);
    }
    tb_free();
    return 0;
}
