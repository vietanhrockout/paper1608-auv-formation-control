# Independent Review — Phase C.0 Gate Round 6

**Reviewer:** GPT/Codex  
**Claude baseline reviewed:** `af1048e` (implementation commit `c6f24c3`)  
**Scope:** Round-6 fail-closed fixes, clean-tree evidence, and the next operational gate before Phase C 100 s.  
**Verdict:** **Checkpoint/resume/Git-binding gate CLOSED. Phase C physical-state run is conditionally greenlit after adding a durable run-and-save wrapper.**

## Round-6 findings verification

### Confirmed fixed: mid-run Git unavailability

`projected_rk4_integrate.m` now treats any of the following as drift/unverifiable and aborts before replacing the last valid checkpoint:

- current fingerprint unavailable;
- launch fingerprint unavailable;
- SHA mismatch;
- dirty-state mismatch.

The previous Boolean short-circuit fail-open path is gone.

### Confirmed fixed: resume dirty-state mismatch

`resume_projected_rk4_run.m` now compares `current_fp.dirty` with `checkpoint.git_dirty` before constructing the propagated launch fingerprint and before invoking the integrator. A same-SHA but newly dirty working tree is rejected before the first resumed step.

### Test seam and evidence assessment

The injected fingerprint seam is narrow and production defaults still call `git_fingerprint()`. C0f exercises the four requested cases through the same decision branches used by production:

1. current fingerprint unavailable at checkpoint time → abort, previous checkpoint untouched;
2. same SHA but dirty mismatch at resume → reject before integration;
3. same SHA but dirty mismatch at a later checkpoint → abort, previous checkpoint untouched;
4. unchanged clean fingerprint → bit-exact final state and matching cumulative step count.

The saved clean-tree evidence reports `available=1`, SHA `c6f24c3...`, and `dirty=0` both before and after C0f. The separate C0c evidence reports a two-interruption chain matching all 9,001 timestamps exactly, with cumulative statistics identical and `dirty=0` before/after. This satisfies the Round-6 acceptance gate. Evidence being captured on the implementation commit and committed afterward is the correct sequence; later commits only add evidence/documentation.

## Remaining pre-run operational finding

### [P0 operational] The production entry point does not durably save the final Phase C result

`exp4_rl_pts_mc_projected.m` returns `res` to the MATLAB workspace but does not save the completed result. There is no dedicated `run_phase_c.m` analogous to `run_phase_b2.m`, which immediately calls `save(...)` after the experiment.

For a ~2.4 h run, relying on an interactive workspace variable is not a sufficient completion contract. A MATLAB/session failure after integration returns but before a manual save could lose the final artifact. The periodic checkpoint reduces the recovery cost but does not replace a named final dataset or a recorded run manifest.

Before launch, add a very small orchestration script (not a controller/integrator change) that:

1. asserts/prints the clean launch fingerprint and intended parameters;
2. calls exactly `exp4_rl_pts_mc_projected(100.0, 1e-4, ..., 1001, false)`;
3. saves the returned `res` to a deterministic Phase-C result path using a temporary file followed by an atomic rename;
4. saves or prints a compact manifest containing SHA, `git_dirty=0`, `t_final`, `h`, `n_target`, parameter/config structs, elapsed time, stored sample count, and online actuator/retraction statistics;
5. writes live console/diary output outside tracked source files so the tree remains clean during checkpoint fingerprint checks;
6. verifies after saving that the artifact reloads, covers `[0,100]`, is finite, and has the expected final timestamp/sample metadata.

Prefer storing the large result outside the tracked repository during the run. It can be copied or deliberately committed later after verification. Do not use `allow_dirty_launch=true`.

## Scientific scope of the greenlight

This closes the **infrastructure/recovery** question and is sufficient to run Phase C for the physical-state evidence at fixed `inverse_lambda_eps=1e-6`.

It does **not** resolve the already documented scientific caveats:

- critic projection thrashing and step-size sensitivity;
- provisional status of cost-to-go/actor figures 4–5;
- `tau_cmd` versus `tau_act` reward interpretation;
- formation-distance/formation-error plotting semantics;
- stale figure-generation pipeline.

Therefore the 100 s run should be labeled a **physical-state production dataset plus provisional RL diagnostics**, not final validation of every paper figure.

## Decision

- **Checkpoint/resume/Git binding:** PASS; no further round is requested on the already tested logic.
- **100 s compute launch:** GO after the durable run-and-save wrapper above is committed and the tree is confirmed clean.
- **Figures/final report:** remain gated by post-run plotting rewrite and the documented RL/semantic caveats.

This review changes no MATLAB implementation file.
