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
            body = ""
            try:
                body = e.read()[:200].decode("utf8", "replace")
            except Exception:
                pass
            print("FETCH retry", url[:110], repr(e)[:120], body, flush=True)
            time.sleep(2 * (i + 1))
    return None

FIELDS = "code,product_name,selected_images,images,image_nutrition_url,nutriments,languages_tags,nutrition_data_per"
groups = [("israel", 30), ("united-states", 8), ("united-kingdom", 8), ("france", 6), ("germany", 6)]
truth = {}
for country, want in groups:
    q = urllib.parse.urlencode({
        "countries_tags_en": country, "fields": FIELDS, "page_size": 100,
        "sort_by": "unique_scans_n", "states_tags": "en:nutrition-facts-completed",
    })
    raw = get("https://world.openfoodfacts.org/api/v2/search?" + q)
    if not raw:
        print("FETCH no search result for", country, flush=True)
        continue
    print("FETCH", country, "products:", len(json.loads(raw).get("products", [])), flush=True)
    got = 0
    prods = json.loads(raw).get("products", [])
    if prods and country == "israel":
        q0 = prods[0]
        print("FETCH sample keys", sorted(q0.keys()), "nutr keys", sorted((q0.get("nutriments") or {}).keys())[:12], "sel", str(q0.get("selected_images"))[:200], flush=True)
    c = {"url": 0, "nutr": 0, "img_ok": 0}
    for p in prods:
        n = p.get("nutriments") or {}
        url = p.get("image_nutrition_url")
        if not url:
            disp = ((p.get("selected_images") or {}).get("nutrition") or {}).get("display") or {}
            if disp:
                url = disp.get("en") or next(iter(disp.values()))
        keys = ["energy-kcal_100g", "proteins_100g", "fat_100g", "carbohydrates_100g"]
        c["url"] += bool(url)
        c["nutr"] += all(n.get(k) is not None for k in keys)
        if not url or any(n.get(k) is None for k in keys):
            continue
        img = get(url.replace(".400.jpg", ".full.jpg")) or get(url)
        if not img or len(img) < 5000:
            continue
        c["img_ok"] += 1
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
    print("FETCH", country, "usable:", got, c, "nutrition selected sample:", str((prods[0].get("selected_images") or {}).get("nutrition"))[:160] if prods else "", "kcalkeys", [k for k in (prods[0].get("nutriments") or {}) if "kcal" in k][:4] if prods else "", flush=True)
json.dump(truth, open(f"{OUT}/truth.json", "w"), ensure_ascii=False)
print("FETCH total", len(truth), flush=True)
if not truth:
    sys.exit(1)
