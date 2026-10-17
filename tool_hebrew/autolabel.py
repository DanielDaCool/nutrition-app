"""Make YOLO labels without hand work: find the number on each photo that equals
Open Food Facts' per-100 g value and box it. Digits only, so English Tesseract
is enough."""
import csv, io, json, os, random, subprocess, sys
from PIL import Image

RAW, OUT = "data/raw", "data/yolo"
CLASSES = ["energy", "protein", "fat", "carbs"]
truth = json.load(open(f"{RAW}/truth.json"))

def words(path):
    r = subprocess.run(["tesseract", path, "-", "-l", "eng", "--psm", "11",
                        "-c", "tessedit_char_whitelist=0123456789.,", "tsv"],
                       capture_output=True, text=True)
    out = []
    for row in csv.DictReader(io.StringIO(r.stdout), delimiter="\t", quoting=csv.QUOTE_NONE):
        t = (row.get("text") or "").strip().strip(".,")
        if not t or not any(c.isdigit() for c in t):
            continue
        try:
            v = float(t.replace(",", "."))
        except ValueError:
            continue
        if len(t) > 1 and t[0] == "0" and t[1].isdigit():
            continue
        x, y, w, h = (int(row[k]) for k in ("left", "top", "width", "height"))
        out.append((v, x, y, w, h))
    return out

def close(a, b):
    return abs(a - b) <= max(0.06 * abs(b), 0.6)

stats = dict(total=0, balance_bad=0, ambiguous=0, missing=0, ok=0)
items = []
for name, t in sorted(truth.items()):
    stats["total"] += 1
    T = [t["kcal"], t["protein"], t["fat"], t["carbs"]]
    if min(T) < 0.5 or T[0] < 5 or abs(4 * T[1] + 9 * T[2] + 4 * T[3] - T[0]) > 0.2 * T[0] + 10:
        stats["balance_bad"] += 1
        continue
    ws = words(f"{RAW}/{name}.jpg")
    boxes = []
    bad = None
    for ci, tv in enumerate(T):
        c = [w for w in ws if close(w[0], tv)]
        if not c:
            bad = "missing"; break
        # the same printed number may repeat in a serving column; keep the one
        # nearest the others' column only when unique
        if len(c) > 1:
            bad = "ambiguous"; break
        boxes.append((ci, c[0]))
    if bad:
        stats[bad] += 1
        continue
    stats["ok"] += 1
    items.append((name, boxes))
print("AUTOLABEL", json.dumps(stats), flush=True)

random.seed(7)
random.shuffle(items)
nval = max(10, len(items) // 6)
for split, part in (("val", items[:nval]), ("train", items[nval:])):
    os.makedirs(f"{OUT}/images/{split}", exist_ok=True)
    os.makedirs(f"{OUT}/labels/{split}", exist_ok=True)
    for name, boxes in part:
        im = Image.open(f"{RAW}/{name}.jpg")
        W, H = im.size
        Image.open(f"{RAW}/{name}.jpg").convert("RGB").save(f"{OUT}/images/{split}/{name}.jpg")
        lines = []
        for ci, (v, x, y, w, h) in boxes:
            pad = 0.15 * h
            x0, y0, x1, y1 = max(0, x - pad), max(0, y - pad), min(W, x + w + pad), min(H, y + h + pad)
            lines.append(f"{ci} {(x0+x1)/2/W:.6f} {(y0+y1)/2/H:.6f} {(x1-x0)/W:.6f} {(y1-y0)/H:.6f}")
        open(f"{OUT}/labels/{split}/{name}.txt", "w").write("\n".join(lines) + "\n")
        json.dump({"truth": truth[name]}, open(f"{OUT}/labels/{split}/{name}.json", "w"))
open(f"{OUT}/data.yaml", "w").write(
    f"path: {os.path.abspath(OUT)}\ntrain: images/train\nval: images/val\nnames:\n"
    + "".join(f"  {i}: {c}\n" for i, c in enumerate(CLASSES)))
print("AUTOLABEL split", len(items) - nval, "train", nval, "val", flush=True)
