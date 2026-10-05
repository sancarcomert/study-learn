#!/usr/bin/env python3
"""dev/render_preview.py
mock_roblox'un dokumunu (parts.txt) okuyup basit bir yazilim 3D cizicisiyle PNG onizleme uretir.
z-buffer + duz golgelendirme + neon "bloom" + mesafe sisi. Gercek Roblox gorunumu DEGIL, yerlesim kontrolu icindir.

Kullanim: render_preview.py parts.txt cikti_klasoru [gorunum_adi ...]
"""
import math
import sys
import numpy as np
from PIL import Image, ImageFilter, ImageChops

W, H = 1280, 720
NEAR = 0.5


def load(path):
    parts = []
    for line in open(path):
        if not line.startswith("P|"):
            continue
        f = line.rstrip("\n").split("|")
        parts.append(
            dict(
                name=f[1],
                shape=f[2],
                mesh=int(f[3]),
                size=np.array([float(f[4]), float(f[5]), float(f[6])]),
                pos=np.array([float(f[7]), float(f[8]), float(f[9])]),
                rot=np.array([float(x) for x in f[10:19]]).reshape(3, 3),
                color=np.array([float(f[19]), float(f[20]), float(f[21])]),
                material=f[22],
                transp=float(f[23]),
                collide=int(f[24]),
                group=f[25],
            )
        )
    return parts


# ---------- birim mesh'ler (yerel uzay, boyut 1) ----------
def unit_box():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)])
    idx = lambda x, y, z: (x * 4 + y * 2 + z)
    quads = [
        (idx(1, 0, 0), idx(1, 1, 0), idx(1, 1, 1), idx(1, 0, 1)),
        (idx(0, 0, 0), idx(0, 0, 1), idx(0, 1, 1), idx(0, 1, 0)),
        (idx(0, 1, 0), idx(0, 1, 1), idx(1, 1, 1), idx(1, 1, 0)),
        (idx(0, 0, 0), idx(1, 0, 0), idx(1, 0, 1), idx(0, 0, 1)),
        (idx(0, 0, 1), idx(1, 0, 1), idx(1, 1, 1), idx(0, 1, 1)),
        (idx(0, 0, 0), idx(0, 1, 0), idx(1, 1, 0), idx(1, 0, 0)),
    ]
    tris = []
    for a, b, c, d in quads:
        tris += [(a, b, c), (a, c, d)]
    return v, np.array(tris)


def unit_cyl(n=18):
    # eksen = X, yaricap 0.5, uzunluk 1
    verts, tris = [], []
    for i in range(n):
        a = i / n * 2 * math.pi
        y, z = 0.5 * math.cos(a), 0.5 * math.sin(a)
        verts.append([-.5, y, z])
        verts.append([.5, y, z])
    verts.append([-.5, 0, 0])
    verts.append([.5, 0, 0])
    c0, c1 = 2 * n, 2 * n + 1
    for i in range(n):
        j = (i + 1) % n
        a0, a1, b0, b1 = 2 * i, 2 * i + 1, 2 * j, 2 * j + 1
        tris += [(a0, a1, b1), (a0, b1, b0), (c1, b1, a1), (c0, a0, b0)]
    return np.array(verts), np.array(tris)


def unit_sphere(nu=12, nv=8):
    verts, tris = [], []
    for j in range(nv + 1):
        t = j / nv * math.pi
        for i in range(nu):
            p = i / nu * 2 * math.pi
            verts.append([0.5 * math.sin(t) * math.cos(p), 0.5 * math.cos(t), 0.5 * math.sin(t) * math.sin(p)])
    for j in range(nv):
        for i in range(nu):
            a = j * nu + i
            b = j * nu + (i + 1) % nu
            c = (j + 1) * nu + i
            d = (j + 1) * nu + (i + 1) % nu
            tris += [(a, c, d), (a, d, b)]
    return np.array(verts), np.array(tris)


BOX, CYL, SPH = unit_box(), unit_cyl(), unit_sphere()

LIGHT = np.array([-0.35, 0.8, 0.5])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


class Camera:
    def __init__(self, pos, target, fov=60):
        self.pos = np.array(pos, float)
        f = np.array(target, float) - self.pos
        f /= np.linalg.norm(f)
        r = np.cross(f, [0, 1, 0])
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.focal = (H / 2) / math.tan(math.radians(fov) / 2)

    def to_cam(self, p):
        d = p - self.pos
        return np.stack([d @ self.r, d @ self.u, d @ self.f], axis=-1)


def clip_near(tri):
    """tri: 3x3 kamera uzayi. z>=NEAR icin kirpilmis ucgenleri dondurur."""
    inside = [v[2] >= NEAR for v in tri]
    n = sum(inside)
    if n == 3:
        return [tri]
    if n == 0:
        return []
    out = []
    pts = []
    for i in range(3):
        a, b = tri[i], tri[(i + 1) % 3]
        ia, ib = a[2] >= NEAR, b[2] >= NEAR
        if ia:
            pts.append(a)
        if ia != ib:
            t = (NEAR - a[2]) / (b[2] - a[2])
            pts.append(a + (b - a) * t)
    if len(pts) == 3:
        out.append(np.array(pts))
    elif len(pts) == 4:
        out.append(np.array([pts[0], pts[1], pts[2]]))
        out.append(np.array([pts[0], pts[2], pts[3]]))
    return out


def draw_tri(cam, tri_cam, color, zbuf, img, glow, emissive, alpha=1.0, write_depth=True):
    for t in clip_near(tri_cam):
        z = t[:, 2]
        sx = W / 2 + t[:, 0] / z * cam.focal
        sy = H / 2 - t[:, 1] / z * cam.focal
        minx, maxx = int(max(0, math.floor(sx.min()))), int(min(W - 1, math.ceil(sx.max())))
        miny, maxy = int(max(0, math.floor(sy.min()))), int(min(H - 1, math.ceil(sy.max())))
        if minx > maxx or miny > maxy:
            continue
        x0, x1, x2 = sx
        y0, y1, y2 = sy
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        xs = np.arange(minx, maxx + 1) + 0.5
        ys = np.arange(miny, maxy + 1) + 0.5
        X, Y = np.meshgrid(xs, ys)
        l0 = ((y1 - y2) * (X - x2) + (x2 - x1) * (Y - y2)) / den
        l1 = ((y2 - y0) * (X - x2) + (x0 - x2) * (Y - y2)) / den
        l2 = 1 - l0 - l1
        mask = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        if not mask.any():
            continue
        w = l0 / z[0] + l1 / z[1] + l2 / z[2]
        d = 1.0 / w
        sub = zbuf[miny:maxy + 1, minx:maxx + 1]
        m = mask & (d < sub)
        if not m.any():
            continue
        if write_depth:
            sub[m] = d[m]
        region = img[miny:maxy + 1, minx:maxx + 1]
        if alpha >= 0.999:
            region[m] = color
        else:
            region[m] = region[m] * (1 - alpha) + color * alpha
        if emissive:
            g = glow[miny:maxy + 1, minx:maxx + 1]
            g[m] = np.maximum(g[m], color * (alpha if alpha < 1 else 1))


def sky_background(cam):
    ys, xs = np.mgrid[0:H, 0:W]
    dirs = (
        cam.f[None, None, :]
        + ((xs[..., None] + 0.5 - W / 2) / cam.focal) * cam.r[None, None, :]
        - ((ys[..., None] + 0.5 - H / 2) / cam.focal) * cam.u[None, None, :]
    )
    dirs /= np.linalg.norm(dirs, axis=-1, keepdims=True)
    e = dirs[..., 1]
    horizon = np.array([0.80, 0.45, 0.72])
    zenith = np.array([0.06, 0.05, 0.20])
    below = np.array([0.10, 0.07, 0.22])
    t = np.clip(e, 0, 1) ** 0.55
    img = horizon[None, None, :] * (1 - t[..., None]) + zenith[None, None, :] * t[..., None]
    neg = np.clip(-e * 2.2, 0, 1)
    img = img * (1 - neg[..., None]) + below[None, None, :] * neg[..., None]
    rng = np.random.default_rng(3)
    stars = rng.random((H, W)) > 0.9985
    img[stars & (e > 0.1)] = 1.0
    return img


def render(parts, cam, name, haze=0.0022):
    img = sky_background(cam)
    sky = img.copy()
    zbuf = np.full((H, W), np.inf)
    glow = np.zeros((H, W, 3))
    transp_pass = []

    for p in parts:
        if p["transp"] >= 0.99:
            continue
        neon = p["material"] == "Neon"
        alpha = 1 - p["transp"]
        if p["material"] == "Glass":
            alpha = min(alpha, 0.5)
        verts, tris = (BOX if p["shape"] == "Block" and not p["mesh"] else
                       CYL if p["shape"] == "Cylinder" else SPH)
        local = verts * p["size"][None, :]
        if p["shape"] == "Ball":
            local = verts * p["size"][0]
        world = local @ p["rot"].T + p["pos"]
        # kaba culling: kamera onunde degilse ve cok uzaksa atla
        c = cam.to_cam(world)
        if (c[:, 2] < NEAR).all():
            continue
        extent = np.linalg.norm(p["size"]) / 2
        dist = np.linalg.norm(p["pos"] - cam.pos)
        if extent / max(dist, 1) < 0.0012:  # <1px
            sx = W / 2 + (c[:, 0].mean() / max(c[:, 2].mean(), NEAR)) * cam.focal
            sy = H / 2 - (c[:, 1].mean() / max(c[:, 2].mean(), NEAR)) * cam.focal
            ix, iy = int(sx), int(sy)
            if 0 <= ix < W and 0 <= iy < H and c[:, 2].mean() < zbuf[iy, ix]:
                img[iy, ix] = p["color"]
                zbuf[iy, ix] = c[:, 2].mean()
                if neon:
                    glow[iy, ix] = p["color"]
            continue
        for tri in tris:
            tv = world[tri]
            n = np.cross(tv[1] - tv[0], tv[2] - tv[0])
            nl = np.linalg.norm(n)
            if nl < 1e-12:
                continue
            n /= nl
            # yuzu kameraya gore cevir (cift yonlu)
            if np.dot(n, cam.pos - tv[0]) < 0:
                n = -n
            if neon:
                col = np.clip(p["color"] * 1.0, 0, 1)
            else:
                lam = max(0.0, float(np.dot(n, LIGHT)))
                shade = 0.50 + 0.62 * lam
                col = np.clip(p["color"] * shade, 0, 1)
            tc = c[tri]
            if alpha < 0.999:
                transp_pass.append((tc, col, alpha, neon))
            else:
                draw_tri(cam, tc, col, zbuf, img, glow, neon)

    for tc, col, alpha, neon in transp_pass:
        draw_tri(cam, tc, col, zbuf, img, glow, neon, alpha=alpha, write_depth=False)

    # mesafe sisi
    finite = np.isfinite(zbuf)
    f = np.where(finite, 1 - np.exp(-np.where(finite, zbuf, 0) * haze), 0.0)
    fog = np.array([0.55, 0.36, 0.62])
    img = img * (1 - f[..., None]) + fog[None, None, :] * f[..., None]
    img = np.where(finite[..., None], img, sky)

    # bloom
    gimg = Image.fromarray((np.clip(glow, 0, 1) * 255).astype(np.uint8))
    b1 = gimg.filter(ImageFilter.GaussianBlur(5))
    b2 = gimg.filter(ImageFilter.GaussianBlur(16))
    out = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    out = ImageChops.add(out, b1.point(lambda v: int(v * 0.55)))
    out = ImageChops.add(out, b2.point(lambda v: int(v * 0.55)))
    return out


VIEWS = {
    # ad: (kamera konumu, hedef, fov)
    "overview": ((0, 175, 310), (0, 18, 0), 62),
    "ground_to_booth1": ((36, 4.5, 0), (80, 9, 0), 66),
    "booth1_close": ((62, 5.5, 7), (80, 6.2, -1), 62),
    "center": ((34, 7, 30), (0, 26, 0), 66),
    "topdown": ((0, 340, 1), (0, 0, 0), 52),
    "far_side": ((330, 22, 230), (0, 40, 0), 60),
    "underside": ((250, -70, 250), (0, -25, 0), 62),
    "plaza_wide": ((0, 9, 118), (0, 14, 0), 78),
}

if __name__ == "__main__":
    parts = load(sys.argv[1])
    outdir = sys.argv[2]
    names = sys.argv[3:] or list(VIEWS)
    print(f"{len(parts)} parca")
    for n in names:
        pos, tgt, fov = VIEWS[n]
        img = render(parts, Camera(pos, tgt, fov), n)
        img.save(f"{outdir}/{n}.png")
        print("yazildi", n)
