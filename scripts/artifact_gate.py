#!/usr/bin/env python3
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "#1 analyst spec": ["docs/product-spec.md"],
    "#2 designer direction": ["docs/design-direction.md", "docs/design-redesign-brief.md"],
    "#3 iOS skeleton": ["ios/AbsTrainer/README.md", "ios/AbsTrainer/Sources/AbsTrainer/WorkoutGenerator.swift"],
    "#5 content asset plan": ["docs/asset-plan.md"],
    "#6 orchestration": ["docs/team-orchestration.md", "docs/ownership-map.md"],
    "#7 Xcode install": ["docs/xcode-install.md"],
    "#8 monetization": ["docs/monetization-roadmap.md"],
}
def main():
    missing=[]
    for group, paths in REQUIRED.items():
        for rel in paths:
            p=ROOT/rel
            if not p.exists() or p.stat().st_size==0:
                missing.append((group,rel))
    if missing:
        print('ARTIFACT GATE: FAIL')
        for group,rel in missing: print(f'- {group}: missing {rel}')
        return 1
    print('ARTIFACT GATE: PASS')
    for group,paths in REQUIRED.items(): print(f'- {group}: {", ".join(paths)}')
    return 0
if __name__ == '__main__': sys.exit(main())
