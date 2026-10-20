#!/usr/bin/env python3
"""data/drafts/*.json をまとめて Okusurhythm/Resources/drugs.json を作る。

SCHEMA.md の形式チェックも行う。エラーがあれば終了コード 1。
  python3 tools/build_drugs.py           # 生成
  python3 tools/build_drugs.py --check   # チェックだけ
"""
import glob
import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRAFTS = ROOT / "data" / "drafts"
OUT = ROOT / "Okusurhythm" / "Resources" / "drugs.json"

DRUG_KEYS = {"id", "genericName", "displayName", "brandNames", "category", "classes",
             "interactions", "foods", "source"}
FOOD_ITEMS = {"grapefruit", "alcohol", "milk", "vitamin_k_foods", "st_johns_wort", "caffeine",
              "potassium_rich", "tyramine_foods", "smoking", "high_fat_meal",
              "iron_calcium_supplements", "other"}
PMDA_URL = re.compile(r"^https://www\.pmda\.go\.jp/PmdaSearch/iyakuDetail/")


def main() -> int:
    errors: list[str] = []
    drugs = []
    for path in sorted(glob.glob(str(DRAFTS / "*.json"))):
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            errors.append(f"{path}: JSON として読めません: {e}")
            continue
        drugs.extend(data["drugs"])

    ids = [d.get("id") for d in drugs]
    for dup in {i for i in ids if ids.count(i) > 1}:
        errors.append(f"id が重複: {dup}")

    for d in drugs:
        where = d.get("id", "?")
        missing = DRUG_KEYS - d.keys()
        if missing:
            errors.append(f"{where}: キーがありません {sorted(missing)}")
            continue
        if not PMDA_URL.match(d["source"].get("url", "")):
            errors.append(f"{where}: 出典 URL が PMDA の添付文書ページではありません")
        if not d["source"].get("revised"):
            errors.append(f"{where}: 改訂年月がありません")
        for i, it in enumerate(d["interactions"]):
            if it.get("level") not in ("contraindicated", "caution"):
                errors.append(f"{where}.interactions[{i}]: level が不正 {it.get('level')}")
            if not it.get("targets"):
                errors.append(f"{where}.interactions[{i}]: targets が空")
            for key in ("targetLabel", "effect"):
                if not it.get(key):
                    errors.append(f"{where}.interactions[{i}]: {key} が空")
            it.setdefault("mechanism", "")
        for i, f in enumerate(d["foods"]):
            if f.get("item") not in FOOD_ITEMS:
                errors.append(f"{where}.foods[{i}]: item が不正 {f.get('item')}")
            if f.get("level") not in ("avoid", "caution"):
                errors.append(f"{where}.foods[{i}]: level が不正 {f.get('level')}")

    # 相手として出てくるが収録していない薬・分類（照合はできないが表示はされる）
    known_ids = set(ids)
    known_classes = {c for d in drugs for c in d.get("classes", [])}
    unmatched = sorted({t for d in drugs for it in d.get("interactions", []) for t in it.get("targets", [])
                        if not (t in known_ids or (t.startswith("class:") and t[6:] in known_classes))})

    print(f"{len(drugs)} 成分、相互作用 {sum(len(d['interactions']) for d in drugs)} 件、"
          f"飲食物 {sum(len(d['foods']) for d in drugs)} 件")
    print(f"収録外の相手（照合対象外）: {len(unmatched)} 件")

    if errors:
        print("\n".join(["エラー:"] + errors), file=sys.stderr)
        return 1
    if "--check" not in sys.argv:
        out = {"version": date.today().isoformat(), "drugs": sorted(drugs, key=lambda d: d["id"])}
        OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"→ {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
