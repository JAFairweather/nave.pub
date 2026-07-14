# deploy/ops — versioned box operations

Reviewable, one-click ops scripts. Each is a small, mostly read-only script you
run through the **Ops** workflow without a full deploy.

## How to run one

Actions → **Ops — run a box command** → `task: run-script` → type the filename
(e.g. `health.sh`) in the `script` field → Run.

The Ops workflow does a **fast, nave.pub-only `git pull`** first (just this repo —
no app repos, no `sites.sh`, no `compose build`), so the script it runs is always
the current version on `main`. That means **adding or editing a script here does
NOT require a full deploy** — commit it and run it. (`deploy/ops/**` is in the
deploy's `paths-ignore`, so script-only pushes skip the box rebuild entirely.)

## The scripts

| script | what it does | writes? |
| --- | --- | --- |
| `health.sh` | containers, disk, docker space, memory, load, brain schedule | no |
| `certs.sh`  | cert expiry (days left) for every vhost, probed on the box | no |
| `disk.sh`   | space report + what's prunable (reclaims nothing itself) | no |

## Adding a script

Drop `deploy/ops/<name>.sh` here, keep it focused and prefer read-only. Commit
and push — no deploy needed. Then run it via `task: run-script`, `script: <name>.sh`.
Reserve destructive actions for `task: custom` so they're never one accidental
click away. The script runs as root on the box from the deploy dir.
