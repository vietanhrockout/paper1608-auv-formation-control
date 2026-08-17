# Independent Review — Phase C Durable Runner

**Reviewer:** GPT/Codex  
**Claude baseline reviewed:** `1116c94` (runner implementation `1281d58`)  
**Scope:** Final operational requirement from `REVIEW_GPT_2026-08-17_R6.md`.  
**Verdict:** **PASS — Phase C.0 infrastructure gate is closed. GO for the 100 s physical-state production run after explicit user approval.**

## Verification

The new production path satisfies the requested completion contract:

- `run_phase_c.m` invokes the intended production wrapper with `t_final=100`, `h=1e-4`, `n_target=1001`, and `allow_dirty_launch=false`.
- Console output is written under the gitignored `phase_c_results/` directory, so the runner does not dirty tracked source files before or during fingerprint checks.
- `run_phase_c_production.m` performs an orchestration-level clean/unavailable Git guard and the underlying experiment performs its own production guard and checkpoint-time drift checks.
- The final trajectory and manifest use deterministic paths and temp-file-plus-rename persistence.
- The manifest records the launch SHA/dirty state, numerical horizon and step, full parameter/config structs, timing, sample count, retraction statistics, and actuator maxima.
- The result is immediately reloaded and checked for the expected variable, finite states, start/end horizon, and sample count.
- A short 0.6 s smoke run exercised save, manifest creation, reload, and verification before the 100 s commitment.
- The real launcher does not use the diagnostic dirty-tree override.

No MATLAB controller, plant, integrator, or runner change is requested in this review.

## Launch conditions

At launch time:

1. confirm `git status --short` is empty;
2. record the HEAD SHA printed by the runner;
3. run only `run_phase_c.m` / `run_phase_c_production` with the committed production arguments;
4. do not edit or commit the repository while integration is active;
5. retain `phase_c_result.mat`, `phase_c_manifest.mat`, `phase_c_console.txt`, and the final checkpoint until post-run validation is complete;
6. require the terminal `VERIFIED` message and inspect the reloaded manifest/result before declaring Phase C complete.

## Scope of approval

This is approval to generate the 100 s dataset for physical-state analysis at the documented fixed `inverse_lambda_eps=1e-6`.

It is not approval to call every paper claim reproduced. The following remain explicitly provisional/open after the run:

- critic projection thrashing and critic-weight step-size sensitivity;
- quantitative interpretation of Figs. 4–5 and RL/cost quantities;
- `tau_cmd`/`tau_act` reward ambiguity;
- formation-distance versus formation-error plotting semantics;
- the stale figure-generation pipeline, which still requires a post-run rewrite and audit.

## Decision

**GO**, subject only to the user's approval for the approximately 2.4-hour compute run. No additional checkpoint/resume/source-binding review round is required before launch.
