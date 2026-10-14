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

FIELDS = "code,product_name,images,nutriments,languages_tags"

def nutrition_image_url(p):
    """URL of the full-size nutrition-table photo from the images dict."""
    code = p["code"]
    if not code.isdigit():
        return None
    code = code.zfill(13)
    folder = f"{code[0:3]}/{code[3:6]}/{code[6:9]}/{code[9:]}"
    imgs = p.get("images") or {}
    keys = sorted(k for k in imgs if k.startswith("nutrition_"))
    # Prefer English, then Hebrew, then anything.
    keys.sort(key=lambda k: (k != "nutrition_en", k != "nutrition_he"))
    for k in keys:
        rev = (imgs[k] or {}).get("rev")
        if rev:
            return f"https://images.openfoodfacts.org/images/products/{folder}/{k}.{rev}.full.jpg"
    return None

groups = [("israel", 40)]
truth = {}
for country, want in groups:
    got = 0
    seen = dict(prods=0, url=0, nutr=0, img_ok=0)
    for page in (1, 2, 3, 4):
        if got >= want:
            break
        q = urllib.parse.urlencode({
            "countries_tags_en": country, "fields": FIELDS, "page_size": 100,
            "page": page, "sort_by": "unique_scans_n",
        })
        raw = get("https://world.openfoodfacts.org/api/v2/search?" + q)
        if not raw:
            print("FETCH no search result for", country, page, flush=True)
            continue
        for p in json.loads(raw).get("products", []):
            seen["prods"] += 1
            n = p.get("nutriments") or {}
            keys = ["energy-kcal_100g", "proteins_100g", "fat_100g", "carbohydrates_100g"]
            url = nutrition_image_url(p)
            seen["url"] += bool(url)
            seen["nutr"] += all(n.get(k) is not None for k in keys)
            if not url or any(n.get(k) is None for k in keys):
                continue
            img = get(url)
            if not img or len(img) < 5000:
                continue
            seen["img_ok"] += 1
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
    print("FETCH", country, "usable:", got, seen, flush=True)

json.dump(truth, open(f"{OUT}/truth.json", "w"), ensure_ascii=False)
print("FETCH total", len(truth), flush=True)
if not truth:
    sys.exit(1)
