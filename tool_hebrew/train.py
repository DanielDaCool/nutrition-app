"""Train a small YOLO on fake tables, then score it on REAL Israeli label photos:
detect the value boxes, read the digits inside with Tesseract, compare with Open
Food Facts' per-100 g values."""
import glob, json, os, shutil, subprocess
from ultralytics import YOLO
from PIL import Image

EPOCHS = int(os.environ.get("EPOCHS", "20"))
IMGSZ = int(os.environ.get("IMGSZ", "512"))
OUT = "data/yolo"
for split in ("train", "val"):
    os.makedirs(f"{OUT}/images/{split}", exist_ok=True)
    os.makedirs(f"{OUT}/labels/{split}", exist_ok=True)
    src = "data/synth_" + split
    for f in glob.glob(f"{src}/images/*.jpg"):
        shutil.move(f, f"{OUT}/images/{split}/")
    for f in glob.glob(f"{src}/labels/*.txt"):
        shutil.move(f, f"{OUT}/labels/{split}/")
open(f"{OUT}/data.yaml", "w").write(
    f"path: {os.path.abspath(OUT)}\ntrain: images/train\nval: images/val\nnames:\n"
    "  0: energy\n  1: protein\n  2: fat\n  3: carbs\n")
print("TRAINSET", len(glob.glob(f"{OUT}/images/train/*.jpg")), len(glob.glob(f"{OUT}/images/val/*.jpg")), flush=True)

model = YOLO("yolo11n.pt")
model.train(data=f"{OUT}/data.yaml", epochs=EPOCHS, imgsz=IMGSZ, batch=16, workers=3,
            device="cpu", project="runs", name="det", exist_ok=True, plots=False,
            verbose=False, fliplr=0.0, mosaic=0.5)
best = YOLO("runs/det/weights/best.pt")

def read_number(crop):
    crop = crop.convert("L")
    crop = crop.resize((max(1, crop.width * 3), max(1, crop.height * 3)))
    crop.save("/tmp/n.png")
    r = subprocess.run(["tesseract", "/tmp/n.png", "-", "--psm", "7", "-c",
                        "tessedit_char_whitelist=0123456789.,"], capture_output=True, text=True)
    t = r.stdout.strip().strip(".,").replace(",", ".")
    try:
        return float(t)
    except ValueError:
        return None

def close(a, b):
    return a is not None and abs(a - b) <= max(0.06 * abs(b), 0.6)

truth = json.load(open("data/raw/truth.json"))
tally = dict(ok=0, wrong=0, missing=0)
detected = dict(found=0, absent=0)
for name, t in sorted(truth.items()):
    T = [t["kcal"], t["protein"], t["fat"], t["carbs"]]
    p = f"data/raw/{name}.jpg"
    res = best.predict(p, imgsz=IMGSZ, conf=0.2, device="cpu", verbose=False)[0]
    im = Image.open(p).convert("RGB")
    pred = {}
    for b in res.boxes:
        c = int(b.cls[0]); cf = float(b.conf[0])
        if c not in pred or cf > pred[c][0]:
            pred[c] = (cf, [float(v) for v in b.xyxy[0]])
    row = []
    for ci in range(4):
        if ci not in pred:
            tally["missing"] += 1; row.append("miss"); continue
        x0, y0, x1, y1 = pred[ci][1]
        v = read_number(im.crop((int(x0), int(y0), int(x1), int(y1))))
        if close(v, T[ci]):
            tally["ok"] += 1; row.append("ok")
        else:
            tally["wrong"] += 1; row.append(f"WRONG({v} vs {T[ci]})")
    print("REAL", name, row, flush=True)
print("RESULT", json.dumps(tally), "photos", len(truth), flush=True)
print("MAPSYN", YOLO("runs/det/weights/best.pt").val(data=f"{OUT}/data.yaml", imgsz=IMGSZ, device="cpu", verbose=False).box.map50, flush=True)
