"""CI-only: Tesseract (Hebrew) on each ML Kit line box, single-line mode."""
import json, subprocess, os
from PIL import Image
pages = json.load(open("tool_probe/pages.json"))
print("ROWDBG", len(pages), len(os.listdir("probe")), sorted(os.listdir("probe"))[:5], pages[0]["id"], flush=True)
for p in pages:
    path = f"probe/{p['id']}.jpg"
    if not os.path.exists(path):
        continue
    im = Image.open(path).convert("L")
    out = []
    for i, l in enumerate(p["page"]["lines"]):
        b = l.get("b")
        if not b:
            continue
        pad = 6
        box = (max(0, b[0]-pad), max(0, b[1]-pad), min(im.width, b[2]+pad), min(im.height, b[3]+pad))
        crop = im.crop(box)
        crop = crop.resize((crop.width*2, crop.height*2))
        crop.save("/tmp/c.png")
        r = subprocess.run(["tesseract", "/tmp/c.png", "-", "-l", "heb+eng", "--psm", "7"],
                           capture_output=True, text=True)
        out.append({"i": i, "t": r.stdout.strip()})
    print("ROWOCR " + json.dumps({"id": p["id"], "rows": out}, ensure_ascii=False), flush=True)
