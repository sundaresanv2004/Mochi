// Direct2D / DirectWrite drawing for AppKitLite on Windows. See include/LiteCanvas.h.
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <d2d1.h>
#include <dwrite.h>
#include <wincodec.h>
#include <algorithm>
#include <vector>
#include "LiteCanvas.h"

namespace {
ID2D1Factory *gFactory = nullptr;
IDWriteFactory *gWrite = nullptr;

bool ready() {
    if (!gFactory && FAILED(D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED, &gFactory))) return false;
    if (!gWrite && FAILED(DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory),
                                              reinterpret_cast<IUnknown **>(&gWrite)))) return false;
    return true;
}

template <class T> void release(T *&p) { if (p) { p->Release(); p = nullptr; } }

D2D1_COLOR_F color(LCColor c) { return D2D1::ColorF(c.r, c.g, c.b, c.a); }
}

struct LCCanvas {
    int32_t width = 0, height = 0;
    HDC dc = nullptr;
    HBITMAP bitmap = nullptr;
    HGDIOBJ previous = nullptr;
    uint8_t *bits = nullptr;
    ID2D1DCRenderTarget *target = nullptr;
    ID2D1SolidColorBrush *brush = nullptr;
    bool drawing = false;
    std::vector<ID2D1Layer *> layers;
    std::vector<ID2D1PathGeometry *> masks;
    D2D1_MATRIX_3X2_F transform = D2D1::Matrix3x2F::Identity();
};

static ID2D1PathGeometry *geometry(LCPath p) {
    ID2D1PathGeometry *g = nullptr;
    if (FAILED(gFactory->CreatePathGeometry(&g))) return nullptr;
    ID2D1GeometrySink *s = nullptr;
    if (FAILED(g->Open(&s))) { g->Release(); return nullptr; }
    s->SetFillMode(p.evenOdd ? D2D1_FILL_MODE_ALTERNATE : D2D1_FILL_MODE_WINDING);
    bool open = false;
    D2D1_POINT_2F start = {0, 0}, current = {0, 0};
    const float *v = p.pts;
    auto begin = [&](D2D1_POINT_2F at) {
        s->BeginFigure(at, D2D1_FIGURE_BEGIN_FILLED);
        open = true; start = at;
    };
    for (int32_t i = 0; i < p.count; i++) {
        switch (p.cmds[i]) {
        case 0: {
            if (open) s->EndFigure(D2D1_FIGURE_END_OPEN);
            current = D2D1::Point2F(v[0], v[1]); v += 2;
            begin(current);
            break;
        }
        case 1: {
            if (!open) begin(current);
            current = D2D1::Point2F(v[0], v[1]); v += 2;
            s->AddLine(current);
            break;
        }
        case 2: {
            if (!open) begin(current);
            D2D1_BEZIER_SEGMENT b = {D2D1::Point2F(v[0], v[1]), D2D1::Point2F(v[2], v[3]), D2D1::Point2F(v[4], v[5])};
            v += 6;
            current = b.point3;
            s->AddBezier(b);
            break;
        }
        case 3: {
            if (open) { s->EndFigure(D2D1_FIGURE_END_CLOSED); open = false; }
            current = start;
            break;
        }
        }
    }
    if (open) s->EndFigure(D2D1_FIGURE_END_OPEN);
    s->Close();
    s->Release();
    return g;
}

extern "C" {

LCCanvas *lc_create(int32_t width, int32_t height) {
    if (!ready() || width <= 0 || height <= 0) return nullptr;
    LCCanvas *c = new LCCanvas();
    c->width = width; c->height = height;
    BITMAPINFO info = {};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;          // top-down
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    HDC screen = GetDC(nullptr);
    c->dc = CreateCompatibleDC(screen);
    ReleaseDC(nullptr, screen);
    void *bits = nullptr;
    c->bitmap = CreateDIBSection(c->dc, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
    if (!c->bitmap) { DeleteDC(c->dc); delete c; return nullptr; }
    c->bits = static_cast<uint8_t *>(bits);
    c->previous = SelectObject(c->dc, c->bitmap);

    D2D1_RENDER_TARGET_PROPERTIES props = D2D1::RenderTargetProperties(
        D2D1_RENDER_TARGET_TYPE_DEFAULT,
        D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED), 96, 96);
    if (FAILED(gFactory->CreateDCRenderTarget(&props, &c->target))) { lc_destroy(c); return nullptr; }
    c->target->SetTextAntialiasMode(D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE);
    c->target->CreateSolidColorBrush(D2D1::ColorF(0, 0, 0, 1), &c->brush);
    return c;
}

void lc_destroy(LCCanvas *c) {
    if (!c) return;
    release(c->brush);
    release(c->target);
    if (c->dc) {
        if (c->previous) SelectObject(c->dc, c->previous);
        DeleteDC(c->dc);
    }
    if (c->bitmap) DeleteObject(c->bitmap);
    delete c;
}

int32_t lc_width(LCCanvas *c) { return c ? c->width : 0; }
int32_t lc_height(LCCanvas *c) { return c ? c->height : 0; }
void *lc_hdc(LCCanvas *c) { return c ? c->dc : nullptr; }
uint8_t *lc_pixels(LCCanvas *c) { GdiFlush(); return c ? c->bits : nullptr; }

int32_t lc_begin(LCCanvas *c) {
    if (!c || c->drawing) return -1;
    RECT r = {0, 0, c->width, c->height};
    if (FAILED(c->target->BindDC(c->dc, &r))) return -2;
    c->target->BeginDraw();
    c->target->SetTransform(D2D1::Matrix3x2F::Identity());
    c->target->Clear(D2D1::ColorF(0, 0, 0, 0));
    c->drawing = true;
    return 0;
}

int32_t lc_end(LCCanvas *c) {
    if (!c || !c->drawing) return -1;
    while (!c->layers.empty()) lc_pop_clip(c);
    HRESULT hr = c->target->EndDraw();
    c->drawing = false;
    GdiFlush();
    return SUCCEEDED(hr) ? 0 : (int32_t)hr;
}

void lc_set_transform(LCCanvas *c, float a, float b, float cc, float d, float tx, float ty) {
    if (!c) return;
    c->transform = D2D1::Matrix3x2F(a, b, cc, d, tx, ty);
    if (c->drawing) c->target->SetTransform(c->transform);
}

void lc_fill(LCCanvas *c, LCPath path, LCColor col) {
    if (!c || !c->drawing) return;
    ID2D1PathGeometry *g = geometry(path);
    if (!g) return;
    c->brush->SetColor(color(col));
    c->target->FillGeometry(g, c->brush);
    g->Release();
}

void lc_stroke(LCCanvas *c, LCPath path, LCColor col, float width, int32_t cap, int32_t join, float miter,
               const float *dashes, int32_t dashCount, float dashPhase) {
    if (!c || !c->drawing || width <= 0) return;
    ID2D1PathGeometry *g = geometry(path);
    if (!g) return;
    D2D1_CAP_STYLE caps[] = {D2D1_CAP_STYLE_FLAT, D2D1_CAP_STYLE_ROUND, D2D1_CAP_STYLE_SQUARE};
    D2D1_LINE_JOIN joins[] = {D2D1_LINE_JOIN_MITER_OR_BEVEL, D2D1_LINE_JOIN_ROUND, D2D1_LINE_JOIN_BEVEL};
    D2D1_CAP_STYLE cs = caps[cap < 0 || cap > 2 ? 0 : cap];
    std::vector<float> scaled;
    for (int32_t i = 0; i < dashCount; i++) scaled.push_back(dashes[i] / width);   // D2D dashes are in stroke widths
    D2D1_STROKE_STYLE_PROPERTIES props = D2D1::StrokeStyleProperties(
        cs, cs, cs, joins[join < 0 || join > 2 ? 0 : join], miter,
        dashCount > 0 ? D2D1_DASH_STYLE_CUSTOM : D2D1_DASH_STYLE_SOLID, dashCount > 0 ? dashPhase / width : 0);
    ID2D1StrokeStyle *style = nullptr;
    gFactory->CreateStrokeStyle(props, dashCount > 0 ? scaled.data() : nullptr, (UINT32)scaled.size(), &style);
    c->brush->SetColor(color(col));
    c->target->DrawGeometry(g, c->brush, width, style);
    release(style);
    g->Release();
}

static ID2D1GradientStopCollection *stops(LCCanvas *c, const LCColor *colors, const float *locations, int32_t n) {
    std::vector<D2D1_GRADIENT_STOP> list;
    for (int32_t i = 0; i < n; i++) list.push_back({locations[i], color(colors[i])});
    ID2D1GradientStopCollection *s = nullptr;
    c->target->CreateGradientStopCollection(list.data(), (UINT32)list.size(), D2D1_GAMMA_2_2, D2D1_EXTEND_MODE_CLAMP, &s);
    return s;
}

void lc_fill_linear(LCCanvas *c, LCPath path, float x0, float y0, float x1, float y1,
                    const LCColor *colors, const float *locations, int32_t n) {
    if (!c || !c->drawing || n < 1) return;
    ID2D1PathGeometry *g = geometry(path);
    ID2D1GradientStopCollection *s = stops(c, colors, locations, n);
    ID2D1LinearGradientBrush *b = nullptr;
    if (g && s && SUCCEEDED(c->target->CreateLinearGradientBrush(
            D2D1::LinearGradientBrushProperties(D2D1::Point2F(x0, y0), D2D1::Point2F(x1, y1)), s, &b))) {
        c->target->FillGeometry(g, b);
    }
    release(b); release(s); release(g);
}

void lc_fill_radial(LCCanvas *c, LCPath path, float cx, float cy, float r0, float r1,
                    const LCColor *colors, const float *locations, int32_t n) {
    if (!c || !c->drawing || n < 1 || r1 <= 0) return;
    ID2D1PathGeometry *g = geometry(path);
    // Direct2D's radial gradients start at the centre: squeeze the stops into [r0/r1, 1].
    std::vector<float> loc;
    for (int32_t i = 0; i < n; i++) loc.push_back(r0 / r1 + (1 - r0 / r1) * locations[i]);
    ID2D1GradientStopCollection *s = stops(c, colors, loc.data(), n);
    ID2D1RadialGradientBrush *b = nullptr;
    if (g && s && SUCCEEDED(c->target->CreateRadialGradientBrush(
            D2D1::RadialGradientBrushProperties(D2D1::Point2F(cx, cy), D2D1::Point2F(0, 0), r1, r1), s, &b))) {
        c->target->FillGeometry(g, b);
    }
    release(b); release(s); release(g);
}

void lc_push_clip(LCCanvas *c, LCPath path) {
    if (!c || !c->drawing) return;
    ID2D1PathGeometry *g = geometry(path);
    if (!g) return;
    ID2D1Layer *layer = nullptr;
    if (FAILED(c->target->CreateLayer(nullptr, &layer))) { g->Release(); return; }
    c->target->PushLayer(D2D1::LayerParameters(D2D1::InfiniteRect(), g, D2D1_ANTIALIAS_MODE_PER_PRIMITIVE), layer);
    c->layers.push_back(layer);
    c->masks.push_back(g);
}

void lc_pop_clip(LCCanvas *c) {
    if (!c || c->layers.empty()) return;
    c->target->PopLayer();
    c->layers.back()->Release(); c->layers.pop_back();
    c->masks.back()->Release(); c->masks.pop_back();
}

int32_t lc_clip_depth(LCCanvas *c) { return c ? (int32_t)c->layers.size() : 0; }

static IDWriteTextLayout *layout(const wchar_t *text, int32_t length, const wchar_t *family, float size, int32_t weight,
                                 float width, float height, int32_t align, int32_t wrap) {
    if (!ready()) return nullptr;
    IDWriteTextFormat *format = nullptr;
    if (FAILED(gWrite->CreateTextFormat(family, nullptr, (DWRITE_FONT_WEIGHT)weight, DWRITE_FONT_STYLE_NORMAL,
                                        DWRITE_FONT_STRETCH_NORMAL, size, L"en-us", &format))) return nullptr;
    DWRITE_TEXT_ALIGNMENT a[] = {DWRITE_TEXT_ALIGNMENT_LEADING, DWRITE_TEXT_ALIGNMENT_CENTER, DWRITE_TEXT_ALIGNMENT_TRAILING};
    format->SetTextAlignment(a[align < 0 || align > 2 ? 0 : align]);
    format->SetWordWrapping(wrap ? DWRITE_WORD_WRAPPING_WRAP : DWRITE_WORD_WRAPPING_NO_WRAP);
    IDWriteTextLayout *l = nullptr;
    gWrite->CreateTextLayout(text, (UINT32)length, format, width, height, &l);
    format->Release();
    return l;
}

void lc_draw_text(LCCanvas *c, const wchar_t *text, int32_t length, const wchar_t *family, float size,
                  int32_t weight, LCColor col, float width, float height, int32_t align, int32_t wrap) {
    if (!c || !c->drawing || length <= 0) return;
    IDWriteTextLayout *l = layout(text, length, family, size, weight, width, height, align, wrap);
    if (!l) return;
    c->brush->SetColor(color(col));
    c->target->DrawTextLayout(D2D1::Point2F(0, 0), l, c->brush, D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT);
    l->Release();
}

void lc_measure_text(const wchar_t *text, int32_t length, const wchar_t *family, float size, int32_t weight,
                     float maxWidth, int32_t align, float *outWidth, float *outHeight) {
    *outWidth = 0; *outHeight = 0;
    bool wrap = maxWidth > 0;
    IDWriteTextLayout *l = layout(length > 0 ? text : L" ", length > 0 ? length : 1, family, size, weight,
                                  wrap ? maxWidth : 100000.0f, 100000.0f, align, wrap);
    if (!l) return;
    DWRITE_TEXT_METRICS m = {};
    if (SUCCEEDED(l->GetMetrics(&m))) {
        *outWidth = length > 0 ? m.widthIncludingTrailingWhitespace : 0;
        *outHeight = m.height;
    }
    l->Release();
}

void *lc_make_icon(LCCanvas *c) {
    if (!c) return nullptr;
    HBITMAP mask = CreateBitmap(c->width, c->height, 1, 1, nullptr);
    ICONINFO info = {};
    info.fIcon = TRUE;
    info.hbmMask = mask;
    info.hbmColor = c->bitmap;
    HICON icon = CreateIconIndirect(&info);
    DeleteObject(mask);
    return icon;
}

int32_t lc_write_png(LCCanvas *c, const wchar_t *path) {
    if (!c) return -1;
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    IWICImagingFactory *wic = nullptr;
    if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&wic)))) return -2;
    // PNG wants straight alpha.
    std::vector<uint8_t> straight(c->bits, c->bits + (size_t)c->width * c->height * 4);
    for (size_t i = 0; i < straight.size(); i += 4) {
        uint8_t a = straight[i + 3];
        if (a > 0 && a < 255) for (int k = 0; k < 3; k++) straight[i + k] = (uint8_t)std::min(255, straight[i + k] * 255 / a);
    }
    HRESULT hr;
    IWICStream *stream = nullptr; IWICBitmapEncoder *enc = nullptr; IWICBitmapFrameEncode *frame = nullptr;
    hr = wic->CreateStream(&stream);
    if (SUCCEEDED(hr)) hr = stream->InitializeFromFilename(path, GENERIC_WRITE);
    if (SUCCEEDED(hr)) hr = wic->CreateEncoder(GUID_ContainerFormatPng, nullptr, &enc);
    if (SUCCEEDED(hr)) hr = enc->Initialize(stream, WICBitmapEncoderNoCache);
    if (SUCCEEDED(hr)) hr = enc->CreateNewFrame(&frame, nullptr);
    if (SUCCEEDED(hr)) hr = frame->Initialize(nullptr);
    if (SUCCEEDED(hr)) hr = frame->SetSize(c->width, c->height);
    WICPixelFormatGUID fmt = GUID_WICPixelFormat32bppBGRA;
    if (SUCCEEDED(hr)) hr = frame->SetPixelFormat(&fmt);
    if (SUCCEEDED(hr)) hr = frame->WritePixels(c->height, c->width * 4, (UINT)straight.size(), straight.data());
    if (SUCCEEDED(hr)) hr = frame->Commit();
    if (SUCCEEDED(hr)) hr = enc->Commit();
    release(frame); release(enc); release(stream); release(wic);
    return SUCCEEDED(hr) ? 0 : (int32_t)hr;
}

}
#endif
