"""CI-only: download nutrition-table photos from Open Food Facts plus their
crowd-sourced per-100g values (ground truth) into probe/."""
import json, os, sys, time, urllib.request, urllib.parse

UA = {"User-Agent": "nutrition-app-ci-probe/0.1 (label OCR check)"}
OUT = "probe"
os.makedirs(OUT, exist_ok=True)

def get(url, tries=4):
    for i in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                return r.read()
        except Exception as e:
            print("retry", url[:90], e, file=sys.stderr)
            time.sleep(2 * (i + 1))
    return None

FIELDS = "code,product_name,image_nutrition_url,nutriments,languages_tags,nutrition_data_per"
groups = [("israel", 30), ("united-states", 8), ("united-kingdom", 8), ("france", 6), ("germany", 6)]
truth = {}
for country, want in groups:
    q = urllib.parse.urlencode({
        "countries_tags_en": country, "fields": FIELDS, "page_size": 100,
        "sort_by": "unique_scans_n", "states_tags": "en:nutrition-facts-completed",
    })
    raw = get("https://world.openfoodfacts.org/api/v2/search?" + q)
    if not raw:
        continue
    got = 0
    for p in json.loads(raw).get("products", []):
        n = p.get("nutriments") or {}
        url = p.get("image_nutrition_url")
        keys = ["energy-kcal_100g", "proteins_100g", "fat_100g", "carbohydrates_100g"]
        if not url or any(n.get(k) is None for k in keys):
            continue
        img = get(url.replace(".400.jpg", ".full.jpg")) or get(url)
        if not img or len(img) < 5000:
            continue
        name = f"{country}_{p['code']}"
        open(f"{OUT}/{name}.jpg", "wb").write(img)
        truth[name] = {
            "product": p.get("product_name"), "country": country,
            "langs": p.get("languages_tags"),
            "kcal": n["energy-kcal_100g"], "protein": n["proteins_100g"],
            "fat": n["fat_100g"], "carbs": n["carbohydrates_100g"],
        }
        got += 1
        if got >= want:
            break
    print(country, got, file=sys.stderr)
json.dump(truth, open(f"{OUT}/truth.json", "w"), ensure_ascii=False)
print("total", len(truth))
