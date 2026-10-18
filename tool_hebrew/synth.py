"""Draw fake Hebrew nutrition tables in a browser, with the exact box of the
per-100 g energy / protein / fat / carbs numbers, then roughen them up like phone
photos. Usage: synth.py OUT_DIR COUNT SEED"""
import json, math, os, random, sys
import cv2
import numpy as np
from playwright.sync_api import sync_playwright

CLASSES = ["energy", "protein", "fat", "carbs"]
FONTS = ["Noto Sans Hebrew", "DejaVu Sans", "FreeSans", "FreeSerif", "Liberation Sans",
         "Liberation Serif", "Frank Ruehl CLM", "David CLM", "Miriam CLM", "Noto Serif Hebrew",
         "Arimo", "sans-serif", "serif"]
NAMES = {
    "energy": ["אנרגיה", "אנרגיה (קלוריות)", "קלוריות", "אנרגיה (קק\"ל)", "ערך אנרגטי (קלוריות)"],
    "fat": ["שומנים", "סך השומנים", "סה\"כ שומנים", "שומן", "שומנים (גרם)"],
    "sat": ["מתוכם רוויים", "שומן רווי", "חומצות שומן רוויות", "מזה שומן רווי"],
    "trans": ["שומן טרנס", "חומצות שומן טרנס", "טרנס"],
    "chol": ["כולסטרול (מ\"ג)", "כולסטרול"],
    "sodium": ["נתרן (מ\"ג)", "נתרן", "נתרן (מג)"],
    "carbs": ["פחמימות", "סך הפחמימות", "סה\"כ פחמימות", "פחמימות (גרם)"],
    "sugars": ["מתוכן סוכרים", "סוכרים", "מתוכם סוכרים", "מהם סוכרים"],
    "fiber": ["סיבים תזונתיים", "סיבים", "סיבים תזונתיים (גרם)"],
    "protein": ["חלבונים", "חלבון", "סך החלבונים", "חלבונים (גרם)"],
}
ENG = {"energy": "Energy", "fat": "Fat", "sat": "Saturated fat", "trans": "Trans fat",
       "chol": "Cholesterol", "sodium": "Sodium", "carbs": "Carbohydrate", "sugars": "Sugars",
       "fiber": "Fibre", "protein": "Protein"}
ORDERS = [
    ["energy", "fat", "sat", "trans", "chol", "sodium", "carbs", "sugars", "fiber", "protein"],
    ["energy", "fat", "sat", "trans", "sodium", "carbs", "sugars", "fiber", "protein"],
    ["energy", "protein", "fat", "sat", "carbs", "sugars", "fiber", "sodium"],
    ["energy", "fat", "sat", "carbs", "sugars", "fiber", "protein", "sodium"],
    ["energy", "protein", "fat", "carbs"],
    ["energy", "fat", "sat", "trans", "carbs", "sugars", "protein", "sodium"],
]
HEADS = ["ערכים תזונתיים", "סימון תזונתי", "טבלת ערכים תזונתיים", "מידע תזונתי", "ערך תזונתי"]
PER100 = ["ל-100 גרם", "ב-100 גרם", "לכל 100 גרם", "ל-100 מ\"ל", "100 גרם", "ב-100 גרם מוצר"]
PERSERV = ["למנה", "למנה (30 גרם)", "לכל מנה", "במנה", "למנה (25 גרם)", "ל-1 מנה (40 גרם)"]
JUNK = ["רכיבים: קמח חיטה, סוכר, שמן צמחי, מלח, חומר תפיחה, ויטמין B1.",
        "יבואן: חברת מזון בע\"מ, רח' הרוקמים 26 חולון.", "ארץ ייצור: ישראל. כשר פרווה.",
        "להיות מאוחסן במקום קריר ויבש.", "מכיל גלוטן וחלב.", "מומלץ לצרוך עד התאריך המופיע על האריזה.",
        "Consumer care: 03-1234567", "תאריך אחרון לשימוש: ראה על האריזה"]

def fmt(v):
    if v >= 10 and random.random() < .6:
        return str(int(round(v)))
    s = f"{v:.1f}"
    return s[:-2] if s.endswith(".0") else s

def make_values():
    fat = random.choice([0, 0.1, 0.5, random.uniform(0.5, 40), random.uniform(1, 60)])
    carbs = random.choice([0.1, random.uniform(0.5, 30), random.uniform(5, 90), random.uniform(40, 95)])
    prot = random.choice([0, 0.4, random.uniform(0.5, 12), random.uniform(3, 30)])
    prot = min(prot, 100 - carbs - fat) if carbs + fat < 100 else 0.5
    prot = max(prot, 0)
    kcal = 4 * prot + 9 * fat + 4 * carbs
    kcal *= random.uniform(.96, 1.04)
    v = dict(energy=round(kcal), fat=round(fat, 1), protein=round(prot, 1), carbs=round(carbs, 1))
    v["sat"] = round(fat * random.uniform(.1, .6), 1)
    v["trans"] = random.choice([0, 0, 0.1, 0.2])
    v["chol"] = random.choice([0, 5, 10, 20, 35])
    v["sodium"] = random.choice([0, 5, 20, 80, 150, 320, 560])
    v["sugars"] = round(carbs * random.uniform(.05, .9), 1)
    v["fiber"] = round(random.uniform(0, 8), 1)
    return v

def build_html():
    v = make_values()
    order = random.choice(ORDERS)
    two = random.random() < .55
    serv_g = random.choice([20, 25, 30, 40, 45, 60])
    font = random.choice(FONTS)
    size = random.randint(15, 30)
    dark = random.random() < .15
    bg = random.choice(["#ffffff", "#fffbe6", "#f3f3f3", "#e8f4e8", "#fdeeee", "#eef3fb", "#fff3d6"]) if not dark else random.choice(["#222", "#5a1a1a", "#12305a", "#144d2a"])
    fg = "#fff" if dark else random.choice(["#000", "#111", "#222", "#2a2a2a", "#4a1010"])
    border = random.choice(["1px solid " + fg, "none", "2px solid " + fg, "1px dotted " + fg])
    zebra = random.random() < .35
    numfirst = random.random() < .75  # numbers to the left of names (normal in RTL)
    rtl = random.random() < .93
    val_cols = 2 if two else 1
    serv_first = two and random.random() < .2
    show_unit = random.random() < .3
    eng = random.random() < .3
    head = random.choice(HEADS)
    bold_names = random.random() < .4
    pad = random.randint(3, 10)
    rows = []
    for k in order:
        name = random.choice(NAMES[k])
        if eng and random.random() < .8:
            name += " " + ENG[k]
        sub = k in ("sat", "trans", "sugars", "fiber")
        s = serv_g / 100
        d100 = fmt(v[k])
        dsv = fmt(v[k] * s) if k not in ("energy", "sodium", "chol") else str(int(round(v[k] * s)))
        if k in ("energy", "sodium", "chol"):
            d100 = str(int(round(v[k])))
        if show_unit:
            u = "קק\"ל" if k == "energy" else ("מ\"ג" if k in ("sodium", "chol") else "ג'")
            d100 += " " + u; dsv += " " + u
        rows.append((k, name, d100, dsv, sub))
    cells = []
    for k, name, d100, dsv, sub in rows:
        nm = f'<td class="n" style="{"padding-right:%dpx;font-size:%dpx" % (pad * 4, size - 2) if sub else ""}">{name}</td>'
        vals = [f'<td class="v"><span {"data-cls=%d" % CLASSES.index(k) if k in CLASSES else ""}>{d100}</span></td>']
        if two:
            vals.append(f'<td class="v s">{dsv}</td>')
        if serv_first:
            vals.reverse()
        tds = (vals + [nm]) if numfirst else ([nm] + vals)
        cells.append("<tr>" + "".join(tds) + "</tr>")
    hdr_cells = []
    h100 = f'<th class="v">{random.choice(PER100)}</th>'
    hs = f'<th class="v">{random.choice(PERSERV)}</th>'
    hv = [h100] + ([hs] if two else [])
    if serv_first: hv.reverse()
    htds = (hv + ['<th class="n"></th>']) if numfirst else (['<th class="n"></th>'] + hv)
    junk = "".join(f"<p>{random.choice(JUNK)}</p>" for _ in range(random.randint(0, 3)))
    junk2 = "".join(f"<p>{random.choice(JUNK)}</p>" for _ in range(random.randint(0, 3)))
    margin = random.randint(20, 90)
    html = f"""<html><body style="margin:0;background:{random.choice(['#ddd','#fff','#c8d8e8','#e8d8c8','#999'])}">
<div style="display:inline-block;margin:{margin}px;padding:{random.randint(8,30)}px;background:{bg};color:{fg};
 font-family:'{font}';font-size:{size}px;direction:{'rtl' if rtl else 'ltr'};width:{random.randint(380, 720)}px">
{junk}
<div style="font-weight:bold;font-size:{size+4}px;margin:6px 0">{head}</div>
<table style="border-collapse:collapse;width:100%;border:{border}">
<tr style="font-weight:bold">{''.join(htds)}</tr>
{''.join(cells)}
</table>{junk2}</div>
<style>td,th{{padding:{pad}px {pad+4}px;border-bottom:{border};text-align:{'right' if rtl else 'left'}}}
td.v,th.v{{text-align:center}} td.n{{{'font-weight:bold' if bold_names else ''}}}
{'tr:nth-child(even){background:rgba(0,0,0,.07)}' if zebra else ''}</style></body></html>"""
    return html

def augment(img, boxes):
    h, w = img.shape[:2]
    # random crop (keep boxes mostly inside)
    if random.random() < .5:
        xs0 = min(b[0] for b in boxes); ys0 = min(b[1] for b in boxes)
        xs1 = max(b[2] for b in boxes); ys1 = max(b[3] for b in boxes)
        x0 = random.randint(0, int(max(0, xs0 - 5))); y0 = random.randint(0, int(max(0, ys0 - 5)))
        x1 = random.randint(int(min(w, xs1 + 5)), w); y1 = random.randint(int(min(h, ys1 + 5)), h)
        img = img[y0:y1, x0:x1]; boxes = [(b[0]-x0, b[1]-y0, b[2]-x0, b[3]-y0, b[4]) for b in boxes]
        h, w = img.shape[:2]
    # perspective
    j = random.uniform(0.0, 0.06)
    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = src + np.float32([[random.uniform(-j, j) * w, random.uniform(-j, j) * h] for _ in range(4)])
    ang = random.uniform(-6, 6)
    M = cv2.getRotationMatrix2D((w / 2, h / 2), ang, random.uniform(.8, 1.1))
    P = cv2.getPerspectiveTransform(src, dst.astype(np.float32))
    H = np.vstack([M, [0, 0, 1]]) @ P
    out_w, out_h = int(w * 1.15), int(h * 1.15)
    T = np.array([[1, 0, (out_w - w) / 2], [0, 1, (out_h - h) / 2], [0, 0, 1]])
    H = T @ H
    border = tuple(int(c) for c in np.random.randint(60, 230, 3))
    img = cv2.warpPerspective(img, H, (out_w, out_h), borderMode=cv2.BORDER_CONSTANT, borderValue=border)
    nb = []
    for x0, y0, x1, y1, c in boxes:
        pts = np.float32([[[x0, y0]], [[x1, y0]], [[x1, y1]], [[x0, y1]]])
        q = cv2.perspectiveTransform(pts, H)[:, 0]
        nb.append((q[:, 0].min(), q[:, 1].min(), q[:, 0].max(), q[:, 1].max(), c))
    # photo-like damage
    if random.random() < .7:
        k = random.choice([3, 5, 7]); img = cv2.GaussianBlur(img, (k, k), 0)
    img = img.astype(np.float32)
    img = img * random.uniform(.6, 1.15) + random.uniform(-30, 30)
    grad = np.linspace(random.uniform(-40, 0), random.uniform(0, 40), out_w)[None, :, None]
    img = img + grad
    img += np.random.normal(0, random.uniform(0, 8), img.shape)
    img = np.clip(img, 0, 255).astype(np.uint8)
    s = random.choice([1.0, 0.75, 0.5])
    if s != 1.0:
        img = cv2.resize(img, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        nb = [(a * s, b * s, c * s, d * s, e) for a, b, c, d, e in nb]
    return img, nb

def main(out, count, seed):
    random.seed(seed); np.random.seed(seed)
    os.makedirs(f"{out}/images", exist_ok=True); os.makedirs(f"{out}/labels", exist_ok=True)
    with sync_playwright() as p:
        br = p.chromium.launch(executable_path=os.environ.get("CHROMIUM_PATH") or None)
        pg = br.new_page(viewport={"width": 1000, "height": 1000})
        n = 0
        while n < count:
            pg.set_content(build_html())
            boxes = pg.evaluate("""() => [...document.querySelectorAll('[data-cls]')].map(e => {
                const r = e.getBoundingClientRect(); return [r.left, r.top, r.right, r.bottom, +e.dataset.cls]; })""")
            if len(boxes) != 4:
                continue
            body = pg.evaluate("() => { const d = document.body.firstElementChild.getBoundingClientRect(); return [d.left, d.top, d.right, d.bottom]; }")
            png = pg.screenshot(full_page=True)
            img = cv2.imdecode(np.frombuffer(png, np.uint8), cv2.IMREAD_COLOR)
            img, nb = augment(img, [tuple(b) for b in boxes])
            h, w = img.shape[:2]
            lines = []
            ok = True
            for x0, y0, x1, y1, c in nb:
                pad = 0.12 * (y1 - y0)
                x0, y0, x1, y1 = x0 - pad, y0 - pad, x1 + pad, y1 + pad
                if x0 < -2 or y0 < -2 or x1 > w + 2 or y1 > h + 2:
                    ok = False
                x0, y0, x1, y1 = max(0, x0), max(0, y0), min(w, x1), min(h, y1)
                if x1 - x0 < 6 or y1 - y0 < 6:
                    ok = False
                lines.append(f"{int(c)} {(x0+x1)/2/w:.6f} {(y0+y1)/2/h:.6f} {(x1-x0)/w:.6f} {(y1-y0)/h:.6f}")
            if not ok:
                continue
            name = f"s{seed}_{n:05d}"
            cv2.imwrite(f"{out}/images/{name}.jpg", img, [cv2.IMWRITE_JPEG_QUALITY, random.randint(35, 90)])
            open(f"{out}/labels/{name}.txt", "w").write("\n".join(lines) + "\n")
            n += 1
        br.close()

if __name__ == "__main__":
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
