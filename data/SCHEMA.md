# 薬データ（drugs.json）のスキーマ

アプリに同梱する飲み合わせ・飲食物データ。**すべての記載は PMDA の医療用医薬品添付文書に基づく**こと。
添付文書に書かれていない内容（一般論・推測）は入れない。

## ファイル形式

```json
{
  "version": "2026-10-20",
  "drugs": [ Drug, ... ]
}
```

### Drug

| キー | 型 | 説明 |
|---|---|---|
| `id` | string | 一般名のローマ字スネークケース。例 `amlodipine` |
| `genericName` | string | 一般名（日本語）。例 `アムロジピンベシル酸塩` |
| `displayName` | string | 利用者向けの短い名前。例 `アムロジピン` |
| `brandNames` | [string] | 代表的な先発品・主な商品名。例 `["ノルバスク", "アムロジン"]` |
| `category` | string | 薬効の分かりやすい分類。例 `降圧薬（カルシウム拮抗薬）` |
| `classes` | [string] | 下記の分類タグ。相互作用の照合に使う |
| `interactions` | [Interaction] | 添付文書の「併用禁忌」「併用注意」 |
| `foods` | [FoodWarning] | 添付文書に記載のある飲食物・嗜好品・サプリ |
| `source` | Source | 出典 |

### Interaction

| キー | 型 | 説明 |
|---|---|---|
| `level` | `"contraindicated"` \| `"caution"` | 併用禁忌 / 併用注意 |
| `targets` | [string] | 相手。他の Drug の `id` または分類タグ（`class:` 接頭辞）。例 `["clarithromycin", "class:strong_cyp3a4_inhibitor"]` |
| `targetLabel` | string | 添付文書での相手の書き方（利用者に表示）。例 `CYP3A4阻害剤（クラリスロマイシン、イトラコナゾール等）` |
| `effect` | string | 臨床症状・措置方法を平易に1〜2文で |
| `mechanism` | string | 機序・危険因子を1文で |

### FoodWarning

| キー | 型 | 説明 |
|---|---|---|
| `item` | string | 次のいずれか（漢方など「食前・食間に飲む」といった飲み方の注意は `other`）: `grapefruit` `alcohol` `milk` `vitamin_k_foods` `st_johns_wort` `caffeine` `potassium_rich` `tyramine_foods` `smoking` `high_fat_meal` `iron_calcium_supplements` `other` |
| `itemLabel` | string | 表示名。例 `グレープフルーツジュース` |
| `level` | `"avoid"` \| `"caution"` | 避ける / 注意 |
| `effect` | string | 何が起きるか・どうすべきかを平易に |

### Source

| キー | 型 | 説明 |
|---|---|---|
| `title` | string | 例 `ノルバスク錠 添付文書` |
| `url` | string | PMDA 添付文書ページの URL（https://www.pmda.go.jp/PmdaSearch/iyakuDetail/... 形式が望ましい） |
| `revised` | string | 添付文書の改訂年月。例 `2024年6月改訂（第2版）` |

## 分類タグ（`classes` と `targets` の `class:` で使う）

迷ったらこの一覧から選ぶ。新しいタグが必要なら追加してよいが、報告すること。

- `nsaid` 非ステロイド性抗炎症薬
- `anticoagulant` 抗凝固薬（ワルファリン、DOAC）
- `antiplatelet` 抗血小板薬（アスピリン、クロピドグレル等）
- `strong_cyp3a4_inhibitor` 強いCYP3A4阻害薬（クラリスロマイシン、イトラコナゾール、リトナビル等）
- `cyp3a4_inducer` CYP3A4誘導薬（リファンピシン、カルバマゼピン、フェニトイン等）
- `statin` HMG-CoA還元酵素阻害薬
- `calcium_channel_blocker` カルシウム拮抗薬
- `arb` アンジオテンシンII受容体拮抗薬
- `ace_inhibitor` ACE阻害薬
- `potassium_sparing_diuretic` カリウム保持性利尿薬
- `antidiabetic` 糖尿病治療薬（血糖降下作用）
- `benzodiazepine` ベンゾジアゼピン系・類似薬（Z薬含む）
- `cns_depressant` 中枢神経抑制作用のある薬
- `ssri` 選択的セロトニン再取り込み阻害薬
- `maoi` MAO阻害薬
- `serotonergic` セロトニン作動薬（トラマドール、トリプタン等）
- `ppi` プロトンポンプ阻害薬
- `h2_blocker` H2受容体拮抗薬
- `antacid_metal` 金属カチオン含有製剤（Mg、Al、Ca、Fe製剤、制酸剤）
- `quinolone` ニューキノロン系抗菌薬
- `tetracycline` テトラサイクリン系抗菌薬
- `macrolide` マクロライド系抗菌薬
- `corticosteroid` 副腎皮質ステロイド
- `qt_prolonging` QT延長を起こしうる薬
- `digitalis` ジギタリス製剤
- `thyroid_hormone` 甲状腺ホルモン
- `bisphosphonate` ビスホスホネート
- `antihistamine` 抗ヒスタミン薬
- `diuretic` 利尿薬（ループ・サイアザイド）
- `fluvoxamine` フルボキサミン（CYP1A2強阻害）
- `antihypertensive` 降圧作用のある薬全般
- `beta_blocker` β遮断薬
- `fibrate` フィブラート系
- `azole_antifungal` アゾール系抗真菌薬
- `hiv_protease_inhibitor` HIVプロテアーゼ阻害薬
- `potassium_supplement` カリウム製剤
- `iodinated_contrast` ヨード造影剤
- `thrombolytic` 血栓溶解薬
- `sglt2_inhibitor` SGLT2阻害薬
- `tricyclic_antidepressant` 三環系抗うつ薬
- `sulfonylurea` スルホニルウレア系
- `thiazide_diuretic` サイアザイド系利尿薬
- `oral_contraceptive` 経口避妊薬・LEP製剤
- `oral_estrogen` 経口エストロゲン製剤
- `anesthetic` 麻酔薬
- `licorice_containing` 甘草含有製剤（漢方薬など）
- `ephedra_containing` 麻黄含有製剤（エフェドリン類含有製剤を含む）
- `antibiotic` 抗菌薬全般（生菌製剤の添付文書が「抗生物質」と書く場合など）
- `opioid` オピオイド
- `antipsychotic` 抗精神病薬
- `antiepileptic` 抗てんかん薬
- `triptan` トリプタン系
- `pde5_inhibitor` PDE5阻害薬
- `nitrate` 硝酸剤・NO供与剤
- `anticholinergic` 抗コリン作用のある薬
- `dopamine_antagonist` ドパミン拮抗薬
- `xanthine_oxidase_inhibitor` キサンチンオキシダーゼ阻害薬
- `immunosuppressant` 免疫抑制薬
- `p_gp_inhibitor` P糖蛋白阻害薬
- `insulin` インスリン製剤
- `beta2_agonist` β2刺激薬
- `xanthine` キサンチン系薬剤（テオフィリン等）
- `catecholamine` カテコールアミン製剤
- `alpha_blocker` α遮断薬
- `carbapenem` カルバペネム系抗菌薬
- `ergot_alkaloid` エルゴタミン・麦角アルカロイド
- `vitamin_d` 活性型ビタミンD3製剤
- `calcium_supplement` カルシウム製剤
- `progestin` 黄体ホルモン製剤

## 注意

- `targets` は空にしない。相手が薬でなく手技などのときは `procedure:xxx` を使う。
- 既存の drug id（data/drafts/*.json の `id`）と同じ成分を相手にするときは、その id を使う。
- 漢方薬は `id` を `kampo_kakkonto` のように `kampo_` で始め、構成生薬に応じて `licorice_containing` などのタグを付ける。
- 併用禁忌・併用注意が添付文書にない薬も収録する（`interactions: []`）。アプリで「記載なし」を出典付きで示せるため。
