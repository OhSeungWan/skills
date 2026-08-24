#!/usr/bin/env python3
"""대장 flows: 를 flow-runner 가 먹는 flows.json 으로 컴파일한다.

사용: python3 compile-flows.py <대상 레포 루트> [출력 경로]
기본 출력: <루트>/.qa/runs/flow-latest/flows.json

path 의 {키}를 config ids 로 치환하고, requires 가 빈 화면의 플로우는
uncovered 로 넘긴다(실행하지 않되 침묵하지 않는다). 지문 키는
<화면>/<source>, 같은 source 가 한 화면에 여럿이면 둘째부터 -2.
"""
import json
import os
import sys

import yaml

root = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(root, ".qa/runs/flow-latest/flows.json")

led = yaml.safe_load(open(os.path.join(root, ".qa/ledger.yaml")))
cfg = yaml.safe_load(open(os.path.join(root, ".qa/config.yaml")))
ids = cfg.get("ids") or {}
w, h = map(int, str(cfg.get("viewport", "390x844")).split("x"))

flows, uncovered = [], []
for sc in led["screens"]:
    fl = sc.get("flows") or []
    if not fl:
        continue
    missing = [k for k in sc.get("requires", []) if not ids.get(k)]
    if missing:
        uncovered.append({"screen": sc["slug"], "flows": len(fl), "missing": missing})
        continue
    path = sc["path"]
    for k, v in ids.items():
        path = path.replace("{%s}" % k, v)
    seen = {}
    for f in fl:
        n = seen.get(f["source"], 0) + 1
        seen[f["source"]] = n
        flows.append({
            "key": f"{sc['slug']}/{f['source']}" + (f"-{n}" if n > 1 else ""),
            "screen": sc["slug"],
            "source": f["source"],
            "confidence": f.get("confidence", "guessed"),
            "path": path,
            "forbidden": sc.get("forbidden") or [],
            "before": f.get("before") or [],
            "steps": f.get("steps") or [],
            "expect": f.get("expect") or [],
        })

os.makedirs(os.path.dirname(out), exist_ok=True)
doc = {
    "meta": {
        "baseURL": cfg["zone_url"],
        "storageState": cfg["storage_state"],
        "viewport": {"width": w, "height": h},
    },
    "flows": flows,
    "uncovered": uncovered,
}
json.dump(doc, open(out, "w"), ensure_ascii=False, indent=1)
print(f"{len(flows)} 검사 컴파일 → {out}" + (f" · 미커버 화면 {len(uncovered)}" if uncovered else ""))
