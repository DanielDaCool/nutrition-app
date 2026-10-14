"""CI-only: run desktop Tesseract (Hebrew) on the probe photos and print JSON."""
import json, subprocess, glob, os
truth = json.load(open("probe/truth.json"))
for name in sorted(truth):
    row = {"id": name, "truth": truth[name]}
    for psm in (3, 4, 6, 11):
        r = subprocess.run(["tesseract", f"probe/{name}.jpg", "-", "-l", "heb+eng",
                            "--psm", str(psm), "-c", "preserve_interword_spaces=1"],
                           capture_output=True, text=True)
        row[f"psm{psm}"] = r.stdout
    print("TESS " + json.dumps(row, ensure_ascii=False), flush=True)
