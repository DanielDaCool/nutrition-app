"""Train a small YOLO on the auto-labelled photos and score it end to end:
detect the value boxes, read the digits inside with Tesseract, compare with OFF."""
import csv, glob, io, json, os, subprocess
from ultralytics import YOLO
from PIL import Image

EPOCHS = int(os.environ.get("EPOCHS", "40"))
model = YOLO("yolo11n.pt")
model.train(data="data/yolo/data.yaml", epochs=EPOCHS, imgsz=640, batch=8, workers=2,
            device="cpu", project="runs", name="det", exist_ok=True, patience=15,
            plots=False, verbose=False)
best = YOLO("runs/det/weights/best.pt")

def read_number(crop):
    crop = crop.convert("L")
    crop = crop.resize((crop.width * 3, crop.height * 3))
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

tally = dict(ok=0, wrong=0, missing=0)
imgs = sorted(glob.glob("data/yolo/images/val/*.jpg"))
for p in imgs:
    name = os.path.basename(p)[:-4]
    t = json.load(open(f"data/yolo/labels/val/{name}.json"))["truth"]
    T = [t["kcal"], t["protein"], t["fat"], t["carbs"]]
    res = best.predict(p, imgsz=640, conf=0.25, device="cpu", verbose=False)[0]
    im = Image.open(p)
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
            tally["wrong"] += 1; row.append("WRONG")
    print("VAL", name, row, flush=True)
print("RESULT", json.dumps(tally), "images", len(imgs), flush=True)
m = YOLO("runs/det/weights/best.pt")
print("MAP", m.val(data="data/yolo/data.yaml", device="cpu", verbose=False).box.map50, flush=True)
