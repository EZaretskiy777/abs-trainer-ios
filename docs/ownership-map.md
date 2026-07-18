# Ownership map

```text
Path / artifact                         Owner        Issue
---------------------------------------------------------------
docs/product-spec.md                    analyst      #1
docs/design-direction.md                designer     #2
design/assets/*                         designer     #2
ios/AbsTrainer/*                        ios          #3
docs/qa-checklist.md                    qa           #4
docs/qa-report.md                       qa           #4
docs/asset-plan.md                      content      #5
assets/exercises/*                      content      #5
docs/approve-checkpoints.md             teamlead     #6
docs/team-orchestration.md              teamlead     #6
docs/ownership-map.md                   teamlead     #6
docs/xcode-install.md                   setup        #7
docs/monetization-roadmap.md            product/tl   #8
scripts/artifact_gate.py                teamlead     #6
.github/workflows/artifact-gate.yml     teamlead     #6
```

## Edit rule
Before closing a task, verify that the owner produced/updated the expected path and linked it in the issue.
