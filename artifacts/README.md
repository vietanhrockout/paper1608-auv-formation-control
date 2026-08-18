# Artifacts

This directory contains committed evidence and historical outputs. Source code does not live here.

- `phase-c/` — accepted 100 s production result, paired manifest and analysis, verification output, and plot audit logs.
- `validation/` — Phase B and Issue P validation trajectories, checker results, and associated logs.
- `diagnostics/` — historical exploratory logs, checkpoints, and intermediate diagnostic evidence.
- `work/` — ignored working output for new long-running simulations. It is created automatically and is not committed.

The large MAT files are retained because current verification and figure generation bind directly to the committed raw artifacts. Historical files are moved, not rewritten, so their hashes and provenance remain intact.

See [`../paper1608/docs/IMPLEMENTATION_STATUS.md`](../paper1608/docs/IMPLEMENTATION_STATUS.md) before interpreting any artifact as an accepted scientific result.
