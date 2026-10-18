"""Collect real Israeli label photos (resized) plus generated, already-labelled
tables into out/ for hand labelling in Roboflow."""
import glob, json, os, shutil
from PIL import Image
OUT = "out"
os.makedirs(f"{OUT}/real_photos", exist_ok=True)
truth = json.load(open("data/raw/truth.json"))
rows = ["file,product,off_kcal,off_protein_g,off_fat_g,off_carbs_g"]
n = 0
for f in sorted(glob.glob("data/raw/*.jpg")):
    name = os.path.basename(f)[:-4]
    im = Image.open(f).convert("RGB")
    im.thumbnail((1600, 1600))
    im.save(f"{OUT}/real_photos/{name}.jpg", quality=85)
    t = truth[name]
    rows.append(f'{name}.jpg,"{(t.get("product") or "").replace(chr(34), "")}",{t["kcal"]},{t["protein"]},{t["fat"]},{t["carbs"]}')
    n += 1
open(f"{OUT}/real_photos/off_values.csv", "w", encoding="utf-8").write("\n".join(rows) + "\n")
print("PACKAGED real", n, flush=True)
for sub in ("images", "labels"):
    os.makedirs(f"{OUT}/generated_labeled/{sub}", exist_ok=True)
for f in sorted(glob.glob("data/synth_train/images/*.jpg"))[:300]:
    name = os.path.basename(f)[:-4]
    shutil.copy(f, f"{OUT}/generated_labeled/images/{name}.jpg")
    shutil.copy(f"data/synth_train/labels/{name}.txt", f"{OUT}/generated_labeled/labels/{name}.txt")
open(f"{OUT}/generated_labeled/data.yaml", "w").write("train: images\nval: images\nnames:\n  0: energy\n  1: protein\n  2: fat\n  3: carbs\n")
