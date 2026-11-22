// Direct2D / DirectWrite drawing for AppKitLite on Windows. Empty on other platforms.
#ifndef LITE_CANVAS_H
#define LITE_CANVAS_H
#ifdef _WIN32
#include <stdint.h>
#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LCCanvas LCCanvas;

/// Path commands: 0 move (x y), 1 line (x y), 2 curve (c1x c1y c2x c2y x y), 3 close.
typedef struct LCPath {
    const int32_t *cmds;
    int32_t count;
    const float *pts;
    int32_t evenOdd;
} LCPath;

typedef struct LCColor { float r, g, b, a; } LCColor;

LCCanvas *lc_create(int32_t width, int32_t height);
void lc_destroy(LCCanvas *c);
int32_t lc_width(LCCanvas *c);
int32_t lc_height(LCCanvas *c);

/// Starts a frame: clears to transparent.
int32_t lc_begin(LCCanvas *c);
/// Ends the frame (pops any clips still pushed). Pixels are then premultiplied BGRA, top row first.
int32_t lc_end(LCCanvas *c);
void *lc_hdc(LCCanvas *c);
uint8_t *lc_pixels(LCCanvas *c);

/// The current transform, user space → pixels: x' = a x + c y + tx, y' = b x + d y + ty.
void lc_set_transform(LCCanvas *c, float a, float b, float cc, float d, float tx, float ty);

void lc_fill(LCCanvas *c, LCPath path, LCColor color);
/// cap: 0 butt, 1 round, 2 square. join: 0 miter, 1 round, 2 bevel. Dash lengths in user units.
void lc_stroke(LCCanvas *c, LCPath path, LCColor color, float width, int32_t cap, int32_t join, float miter,
               const float *dashes, int32_t dashCount, float dashPhase);
void lc_fill_linear(LCCanvas *c, LCPath path, float x0, float y0, float x1, float y1,
                    const LCColor *colors, const float *locations, int32_t stopCount);
void lc_fill_radial(LCCanvas *c, LCPath path, float cx, float cy, float r0, float r1,
                    const LCColor *colors, const float *locations, int32_t stopCount);
/// Clips everything drawn until the matching lc_pop_clip to the path (with the current transform).
void lc_push_clip(LCCanvas *c, LCPath path);
void lc_pop_clip(LCCanvas *c);
int32_t lc_clip_depth(LCCanvas *c);

/// Draws text in a box whose top-left corner is the user-space origin of the current transform
/// (the caller flips it upright). align: 0 left, 1 centre, 2 right.
void lc_draw_text(LCCanvas *c, const wchar_t *text, int32_t length, const wchar_t *family, float size,
                  int32_t weight, LCColor color, float width, float height, int32_t align, int32_t wrap);
/// The size the text needs: no wrapping when maxWidth <= 0.
void lc_measure_text(const wchar_t *text, int32_t length, const wchar_t *family, float size, int32_t weight,
                     float maxWidth, int32_t align, float *outWidth, float *outHeight);

/// An HICON made from the frame (for the tray). Free it with DestroyIcon.
void *lc_make_icon(LCCanvas *c);

/// Saves the frame as a PNG (for `--render`). Returns 0 on success.
int32_t lc_write_png(LCCanvas *c, const wchar_t *path);

#ifdef __cplusplus
}
#endif
#endif
#endif
