"""CI-only: download the nutrition photo of each recorded page's product."""
import json, os, time, urllib.request
UA = {"User-Agent": "nutrition-app-ci-probe/0.1 (label OCR check)"}
os.makedirs("probe", exist_ok=True)
def get(url, tries=6):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return r.read()
        except Exception as e:
            time.sleep(2 * (i + 1))
    return None
ok = 0
for p in json.load(open("tool_probe/pages.json")):
    code = p["id"].split("_", 1)[1]
    raw = get(f"https://world.openfoodfacts.org/api/v2/product/{code}.json?fields=code,images")
    if not raw:
        print("NOPROD", code, flush=True); continue
    imgs = (json.loads(raw).get("product") or {}).get("images") or {}
    c = code.zfill(13)
    folder = f"{c[0:3]}/{c[3:6]}/{c[6:9]}/{c[9:]}"
    rev = (imgs.get("nutrition_he") or {}).get("rev")
    if not rev:
        print("NOIMG", code, flush=True); continue
    img = get(f"https://images.openfoodfacts.org/images/products/{folder}/nutrition_he.{rev}.full.jpg")
    if img:
        open(f"probe/{p['id']}.jpg", "wb").write(img); ok += 1
print("FETCHED", ok, flush=True)
