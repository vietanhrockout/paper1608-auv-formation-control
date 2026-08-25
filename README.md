# Paper 1608 — RL predefined-time formation control for uncertain AUVs

[![MATLAB Fast Verification](https://github.com/vietanhrockout/paper1608-auv-formation-control/actions/workflows/matlab-fast-verification.yml/badge.svg)](https://github.com/vietanhrockout/paper1608-auv-formation-control/actions/workflows/matlab-fast-verification.yml)
[![Release](https://img.shields.io/github/v/release/vietanhrockout/paper1608-auv-formation-control?include_prereleases)](https://github.com/vietanhrockout/paper1608-auv-formation-control/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

MATLAB implementation and audited reproduction workspace for:

> Guo, Xiao, Shen, Chen, Guo, and Luo, “Reinforcement learning predefined-time formation control for uncertain AUVs with disturbance and input saturation,” *Neurocomputing*, vol. 677, 133031, 2026.

## Current status

This repository has reached the **physical-state reproduction milestone**, but it is not a complete quantitative reproduction of every result in the paper.

| Area | Status | Evidence |
| --- | --- | --- |
| 6-DOF AUV dynamics, formation controller, anti-windup, actor–critic structure | Implemented and audited | [`paper1608/docs/EQUATION_MAPPING.md`](paper1608/docs/EQUATION_MAPPING.md) |
| Phase C production simulation | Complete: 100 s, 1,000,000 fixed RK4 steps | [`artifacts/phase-c/phase_c_production_console.txt`](artifacts/phase-c/phase_c_production_console.txt) |
| Physical-state Figs. 2, 3, 6, 7, 8, 9 | Accepted for the **superseded** `tau_cmd_raw` dataset; the regenerated render is **not yet independently re-accepted** | [`paper1608/docs/REVIEW_GPT_2026-08-17_R11.md`](paper1608/docs/REVIEW_GPT_2026-08-17_R11.md) |
| Fast verification suite | 46 passed, 0 failed, 14 integration oracles deferred | [`artifacts/phase-c/phase_c_verification_suite_console.txt`](artifacts/phase-c/phase_c_verification_suite_console.txt) |
| Figs. 4–5 and quantitative RL/critic claims | Provisional mismatch diagnostics, not accepted reproductions | [`paper1608/docs/IMPLEMENTATION_STATUS.md`](paper1608/docs/IMPLEMENTATION_STATUS.md) |

The committed Phase C dataset reaches the accepted tracking neighborhood by the combined 10 s horizon and remains bounded through 100 s. It **does not reproduce the literal 5 s reaching deadline**: the observed small-neighborhood entry is approximately 7.1–7.5 s. This boundary is intentional and is enforced by the verification suite.

## Requirements

- MATLAB R2025b for the pinned CI environment.
- Git, if using checkpoint provenance and clean-tree guards.
- No paper PDF is included because the source article is copyrighted.

The code may work on other recent MATLAB releases, but CI only guarantees the pinned version above.

## Quick start

Clone the repository and run the fast verification gate from MATLAB:

```matlab
cd paper1608
results = run_all_verifications(false);
```

The expected summary is:

```text
46 passed, 0 failed, 14 deferred
```

The 14 deferred integration oracles are listed with individual reasons. They are not silently treated as passing, and some legacy adaptive-solver paths are known to stall or have been invalidated.

To regenerate the six accepted physical-state figures from the committed 100 s artifacts:

```matlab
addpath(genpath('paper1608'))
generate_all_paper_figures()
```

To also render the explicitly provisional Fig. 4–5 diagnostics:

```matlab
generate_all_paper_figures([], [], true)
```

Do not present those two figures as quantitative reproductions; their rendered images contain the same warning.

## Production simulation

The accepted Phase C output is already committed under `artifacts/phase-c/`, with its paired manifest and analysis artifacts. Re-running it is expensive and is not required for normal verification.

To deliberately launch a fresh 100 s run from a clean Git tree:

```bash
matlab -batch "run('run_phase_c.m')"
```

The recorded run took 138.2 minutes under the corrected Eq. (16) reward; the superseded `tau_cmd_raw` run took 200.7 min. The runner checkpoints, refuses dirty-tree launches by default, detects repository drift during execution, saves atomically, and verifies the saved result.

## Repository layout

- `paper1608/` — maintained MATLAB implementation, verification suite, plots, and implementation documentation.
- `paper1608/config/` — paper, simulation, saturation, and neural-network parameters.
- `paper1608/model/` — 6-DOF AUV model and earth/body-frame transformations.
- `paper1608/control/` — model-based and RL predefined-time control laws.
- `paper1608/nn/` — actor–critic basis, outputs, updates, and projection.
- `paper1608/simulation/` — experiment runners and projected-RK4 production path.
- `paper1608/verify/` — fast oracles, deferred integration tests, and diagnostics.
- `paper1608/plots/` — accepted physical plots and provisional RL diagnostics.
- `paper1608/docs/` — maintained equation mapping, assumptions, audit trail, and current status.
- `artifacts/` — organized production, validation, and historical diagnostic evidence.
- `scripts/` — validation and diagnostic launchers moved out of the repository root.
- `docs/` — documentation index, chronological handoff, reviewer notes, and paper-reference notes.
- `run_phase_c.m` — the single root-level production launcher.

## Reproduction boundaries

The main unresolved items are tracked in [GitHub Issues](https://github.com/vietanhrockout/paper1608-auv-formation-control/issues):

- paper-unspecified numerical values for `R`, `B`, `delta_c`, `delta_a`, and actuator limits;
- early-transient critic projection sensitivity;
- quantitative mismatch of Figs. 4–5;
- disposition of the 14 deferred integration oracles.

See [`paper1608/docs/IMPLEMENTATION_STATUS.md`](paper1608/docs/IMPLEMENTATION_STATUS.md) before making scientific claims from this repository.

## License and citation

The source code in this repository is available under the [MIT License](LICENSE). The underlying article, its text, and its figures remain the property of their respective copyright holders and are not relicensed here.

If you use this implementation, cite the original paper above and identify this repository version or Git tag so the numerical assumptions are traceable.
