# Team orchestration process

## Core rule
Status is not progress. Progress requires: artifact, link to artifact, next step/handoff.

The teamlead is responsible for launching execution when a task is marked `In Progress` but no work has actually started.

## Required gates

### Start gate
A task may enter `status:in-progress` only with owner/role, expected artifact path, acceptance criteria, and next checkpoint time.

### Artifact gate
Every `status:in-progress` issue must have a commit, document, mockup/image, source code, asset table/file, or issue comment with result + link. If missing: add `risk:no-artifact`, add `needs-artifact`, set EOD artifact, split/reassign/produce minimal deliverable.

### Done gate
A task can be closed only if the closing comment contains result summary, artifact link, acceptance note, and handoff/downstream next role. Done without handoff is incomplete.

### Handoff gate
When a role finishes work, teamlead must update downstream issues.

```text
Analyst Done → Design receives screens/style constraints
Analyst Done → iOS receives models/generator/scope
Analyst Done → QA receives acceptance criteria
Analyst Done → Content receives exercise/media table
```

### Stale escalation
If an `In Progress` issue has no new artifact for two artifact-control checks: mark risk, comment required artifact, produce minimal deliverable or split/reassign, report escalation to user.

## Role artifact contract

```text
Analyst   docs/product-spec.md + handoff
Designer  docs/design-direction.md and/or design artifact
Content   docs/asset-plan.md and asset files/links
iOS       ios/AbsTrainer/* + build notes + commit
QA        docs/qa-checklist.md + test report
Setup     docs/xcode-install.md
TL        docs/approve-checkpoints.md + orchestration docs + status reports
```

## Recurring controls
- 09:00 MSK: daily status.
- Every 2 hours daytime: artifact control.
- 18:30 MSK: evening summary.

Reports must distinguish status from verifiable progress.
