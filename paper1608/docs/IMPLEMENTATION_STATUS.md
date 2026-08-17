# Implementation Status

Quick-glance status for anyone (human or LLM) picking up this project cold.
`handoff.md` is the authoritative, detailed log — this file is a compressed
pointer into it, updated at verified checkpoints, not every edit.

## Completed

- Full 6-DOF kinematics/dynamics, sliding surface, reaching law, anti-windup,
  actor-critic NN structure, and the RL predefined-time SMC control law
  (Eq. 1–2, 5–6, 14, 16–17, 19–25, 30–34, 37–38, 55–57) — implemented and
  verified against the raw paper PDF text. See `EQUATION_MAPPING.md`.
- Working production integrator: fixed-step, per-stage-projected RK4
  (`simulation/projected_rk4_integrate.m` + `simulation/exp4_rl_pts_mc_projected.m`).
  Plain `ode45` and a hot/cold hybrid integrator were both tried and proven
  to fail (stiffness at the critic-weight projection boundary defeats both
  explicit and implicit adaptive solvers) before landing on this approach.
- **Issue O (closed-loop formation error did not converge) — RESOLVED.**
  Root cause: **Issue P**, a genuine algebraic sign inconsistency between the
  paper's own Eq. (23) (`Λ1=diag{|υ|^(α1-1)}`, unsigned) and Eq. (31)'s
  literal `sig^(1-α1)(υ)` (signed) — confirmed by pure algebra (Step P.1)
  and by a closed-loop A/B test (Steps P.2/P.3). Fix promoted to the
  production default (`params.inverse_lambda_mode='proof_consistent_unsigned'`,
  user-confirmed). Full 15s validation (Phase B.3) passed with a real
  assert-based checker: `E_chi` collapses 16.0 → 0.0037 over 15s, converging
  shortly after the paper's own claimed `T1*=5s`.
- **Phase C.0 Gate, round 1** (first GPT audit pass): stale
  `exp4_rl_pts_mc_hybrid`/`exp4_rl_pts_mc` (ode45) references removed from
  `handoff.md` and `run_all_experiments.m` in favor of the sole production
  path `exp4_rl_pts_mc_projected`; integrator made memory-safe (decimated
  storage + checkpointing, was ~4.4GB at h=1e-4/100s); Phase B.3's
  convergence-neighborhood check upgraded from a print to a real assert;
  `generate_all_paper_figures.m` guarded against accidental use (wrong
  figure numbering, only Fig.2 matches the real paper). **This round's own
  "complete" claim was itself premature** — see round 2.
- **Phase C.0 Gate, round 2** (second GPT audit pass,
  `REVIEW_GPT_2026-08-16.md`, committed directly to the repo): checkpoint
  is now genuinely resumable (`opts.resume`, atomic writes, verified
  bit-exact equivalence to an uninterrupted run in
  `diagnose_stepC0b_checkpoint_resume_equivalence.m`); decimation/
  checkpointing verified bit-exact equivalent to `store_stride=1` at every
  shared timestamp (`diagnose_stepC0a_decimation_equivalence.m`); `main.m`
  no longer crashes uncaught at Step 3; the integrator now has true
  online (every-step) finiteness assertion and per-channel-group
  (force/moment) actuator tracking, consumed by the B.3 checker in
  addition to its decimated-sample checks; P.1b rewritten as a
  trajectory-level, all-AUV, multi-metric audit with a structured saved
  verdict (see result below once the run completes).

- **Phase C.0 Gate, round 3** (third GPT audit pass,
  `REVIEW_GPT_2026-08-16_R2.md`): round 2's resume fix never actually
  exercised the production wrapper (`resume_projected_rk4_run.m`) or a
  same-target interruption; a resumed run couldn't reconstruct the full
  pre-crash decimated history needed for Phase C figures; nothing bound
  a checkpoint to the exact `t_final`/`h`/`params`/`sat_cfg`/`cfg` it was
  produced under (silent hybrid-trajectory risk); online actuator maxima
  didn't carry forward across resume; P.1b v2 still only compared single
  `tau_act` scalars. All fixed: checkpoints now persist `store_stride`,
  `t_hist_partial`/`X_hist_partial`, and the full config; the wrapper
  hard-fails on any config mismatch and stitches a complete `[0,t_final]`
  history; a controlled `opts.max_steps` test hook lets the acceptance
  test simulate a same-target crash properly. The fix's OWN first test
  run caught an additional self-introduced bug (store_stride mismatch
  causing a density discontinuity at the resume boundary) — fixed too.
  **Verified**: full-history stitch, all cumulative stats (including
  actuator maxima), and final state all match an uninterrupted run
  exactly (`0.000000e+00`); a negative test confirms mismatched-target
  resume is correctly rejected. P.1b rewritten (v3) to compare full
  `tau_act` trajectories with a separate PASS/FAIL verdict per metric
  group (physical/command/actuator/retraction) instead of one blended
  number.
- **P.1b v3 final result** (per-metric-group verdict, see `handoff.md`
  for full numbers): **PHYSICAL STATE (E_chi, E_s): PASS** (rel spread
  ~2-3e-7) — this is what Issue O/P's convergence claim and Figs.
  2,3,6,7,8,9 depend on. COMMAND (tau_cmd): FAIL (5.4% rel spread).
  ACTUATOR (tau_act force/moment): FAIL (moment 33% rel spread,
  21.2→25.7 Nm). RETRACTION (max_retraction): FAIL (17.3% rel spread,
  monotonically decreasing as eps grows — mechanistically sensible,
  larger eps softens the near-v=0 singularity). **Conclusion (GPT's
  interpretation, adopted)**: this does NOT block Phase C at the fixed
  `eps=1e-6` default for physical Figs. 2,3,6,7,8,9. It DOES mean Figs.
  4,5 stay provisional and any future report must document eps as an
  explicit numerical-implementation assumption, same tier as
  tau_max/R/B/delta_c/delta_a.
- **Phase C.0 Gate, round 4** (fourth GPT audit pass,
  `REVIEW_GPT_2026-08-17_R3.md`): round 3's resume fix only proved a
  SINGLE interruption; a second crash during an already-resumed call
  would have lost the original `[0,t1]` history prefix (checkpoints
  written mid-resume only carried their own new segment). Fixed: a
  resumed call now seeds its own output arrays with any inherited
  prefix, so every checkpoint always carries the full history from
  t=0. Verified with a genuinely harder test than any prior round —
  `diagnose_stepC0c_multi_resume_equivalence.m`: original launch → crash
  #1 → resume #1 (production wrapper) → crash #2 → resume #2 (production
  wrapper) → completion, compared bit-exact (`0.000000e+00`) against an
  uninterrupted baseline across all 9001 shared timestamps. Also:
  checkpoints now bind to the git commit SHA + dirty-tree state (shared
  `git_fingerprint.m` utility) — resume hard-fails on a SHA mismatch,
  and the production entry point refuses to launch a fresh checkpointed
  run from a dirty tree by default. Plus two wording fixes: the
  "uniform density" docstring claim was softened to what round 3's fix
  actually guarantees (same stride, not a strictly uniform grid — one
  off-grid sample possible per resume boundary), and the eps-sensitivity
  "up-to-21%"/"33%" conflation in this file's Known Discrepancies section
  was reconciled (they're different quantities, now stated separately).
- **Phase C.0 Gate, round 5** (fifth GPT audit pass,
  `REVIEW_GPT_2026-08-17_R4.md`): round 4's git-binding was CWD-dependent
  (`git rev-parse HEAD` resolves relative to MATLAB's working directory,
  not this repo specifically) and re-sampled the fingerprint fresh at
  every checkpoint instead of fixing it once at launch (a mid-run commit
  could silently relabel later checkpoints). Fixed: `git_fingerprint.m`
  now anchors to its own file location via `mfilename('fullpath')`
  (`git -C <dir>`), verified CWD-independent by
  `diagnose_stepC0d_cwd_independent_fingerprint.m` (changes CWD to a
  temp dir outside the repo, confirms the SHA is unchanged). The launch
  fingerprint is now captured once and threaded through every
  checkpoint/resume in a chain, with a fresh re-check at each checkpoint
  that ABORTS (before overwriting the last valid checkpoint) on any
  drift. New `diagnose_stepC0e_git_binding_integrity.m` (4/4 sub-tests
  PASS): anchored SHA available; SHA identical across an entire resume
  chain (not just coincidentally matching); a mutated/fake SHA is
  rejected on resume with the on-disk checkpoint file left untouched;
  an unavailable git fingerprint fails closed. Also fixed: the
  production checkpoint path was CWD-relative, now resolved to an
  absolute repo-anchored path.
- **Phase C.0 Gate, round 6** (sixth GPT audit pass,
  `REVIEW_GPT_2026-08-17_R5.md`): round 5's fail-closed drift check
  still failed OPEN when EITHER the launch or current git fingerprint
  was unavailable (the `&&`-gated condition short-circuited to false),
  and resume compared HEAD SHA only, never working-tree dirty state --
  an uncommitted edit to a tracked file (SHA unchanged) would resume
  undetected. Both fixed: drift now aborts on ANY of
  {launch-unavailable, current-unavailable, SHA-mismatch,
  dirty-mismatch}; resume checks dirty-state equality before the first
  resumed step. New `diagnose_stepC0f_live_drift_rejection.m` (4/4 PASS,
  using injectable mock-fingerprint test seams rather than touching real
  git state) exercises exactly the 4 scenarios GPT specified: mocked
  unavailable/dirty-mismatch at both checkpoint-time and resume-time
  correctly abort/reject with the last valid checkpoint provably
  untouched; the unmocked happy path remains bit-exact. Also captured
  genuine `dirty=0` clean-tree evidence (see `handoff.md`) by keeping
  diagnostic output outside the repo during the actual test run,
  addressing round 5's own honestly-flagged diary-logging nuance.
  **Clean-tree evidence captured and satisfies GPT's full Round 6
  acceptance gate**: both `diagnose_stepC0f_live_drift_rejection.m` and
  `diagnose_stepC0c_multi_resume_equivalence.m` reran from the session
  scratchpad (outside the repo), confirming `available=1`,
  `sha=c6f24c3...`, `dirty=0` at both PRE-run and POST-run, with the
  multi-resume chain still bit-exact (`0.000000e+00` across 9001
  timestamps). See `c0f_clean_tree_evidence.txt` /
  `c0c_clean_tree_evidence.txt`.
- **Phase C.0 Gate: CLOSED** (seventh GPT audit pass,
  `REVIEW_GPT_2026-08-17_R6.md`) — explicit verdict: "Checkpoint/resume/
  Git-binding gate CLOSED... no further round is requested on the
  already tested logic." One final operational gap (not part of the
  checkpoint/resume mechanism itself): `exp4_rl_pts_mc_projected.m`
  never persisted its result to disk, relying on a workspace variable
  surviving until a manual `save()` -- insufficient for a ~2.4hr run.
  Fixed: new `paper1608/simulation/run_phase_c_production.m` +
  `run_phase_c.m` (durable run-and-save wrapper: launch-fingerprint
  guard, atomic save of result+manifest, reload-and-verify, console
  output kept outside git tracking). Sanity-tested on a 0.6s horizon
  before trusting for the real 100s commitment -- save/manifest/verify
  all correct. **Phase C launch: GO**, pending explicit user go-ahead
  for the ~2.4hr compute commitment. Scientific scope of this greenlight
  is infrastructure/recovery only -- Issue M/K, Figs. 4-5, and the plot
  pipeline rewrite remain open per GPT's explicit framing (see
  `handoff.md`).
- **PHASE C 100s RUN COMPLETE** — user gave explicit go-ahead, launched
  via `run_phase_c.m`. First launch attempt was correctly REJECTED by
  the fail-closed guard (a stray untracked file from the shell's own
  stdout redirect made the tree dirty) -- a genuine, unplanned
  confirmation the round-6 logic works, not just a synthetic test.
  Relaunched cleanly (`dirty=0`, sha `1d8e1f8`). Result: 1,000,000
  steps, 200.7 min wall, 1003 samples, self-verified. **E_chi collapses
  16.0 -> ~0.003-0.015 by t~7.5s and STAYS THERE for the full remaining
  90s** (first genuine long-horizon stability confirmation, not just a
  short transient) -- global min 2.56e-3 at t=10.79s, end value 0.0146.
  All 3 AUVs converge individually. All structural checks PASS (finite,
  NN bounds, actuator limits respected exactly at saturation). Full
  writeup with per-timestep table in `handoff.md`. Evidence committed:
  `phase_c_result_t100.mat`, `phase_c_manifest_t100.mat`,
  `phase_c_analysis_t100.mat`, `phase_c_production_console.txt`.

## In progress

None on the infrastructure/Issue-O/P front — Phase C's 100s dataset is
in hand and structurally verified. Remaining work is the plot pipeline
rewrite (Figs. 2,3,6,7,8,9 from this real dataset) and the still-open
Issue M/K critic-weight-thrashing / Figs.4-5-provisional questions,
neither of which is new -- both were already tracked before this run
and are unaffected by it either way.

## Known discrepancies / open questions

- **Issue M** (critic reward `τ_cmd` vs `τ_act` in Eq. 16): unresolved
  reproduction choice. Fig. 4's `O(10^8)` cost-to-go magnitude favors raw
  `τ_cmd`, but that argument is conditioned on this project's own assumed
  `R=1e-4·I`. Default remains `'tau_cmd_raw'`.
- **Issue M/K critic-weight projection thrashing**: even after the Issue P
  fix, `total_retracted` stays enormous (641,485 of 150,000 RK4 steps in
  Phase B.3) — the critic NN weight trajectory is effectively noise-level
  step-size-sensitive (`max|ΔWc|≈11%` of `δc` between h=1e-4 and h=1e-5,
  Step P.4). Physical-state figures (2,3,6,7,8,9) are on solid ground;
  cost-to-go/critic figures (4,5) are not yet quantitatively trustworthy.
- **Step L.3a** (follower formation-error architecture): paper-literal
  Candidate A (`χᵢ=ηᵢ-η_d0-η^l_0i`, current code) now converges cleanly
  under the Issue P fix. Candidate B (`χᵢ=ηᵢ-η₀-η^l_0i`, actual-leader-
  relative) was found to better match Fig. 7–8's sign/scale in an earlier
  pass but has not been re-tested under the fix. For Fig. 7 specifically
  (paper describes it as "formation distance between follower and leader"),
  Phase C's plotting code should compute actual `η₁-η₀`/`η₂-η₀` directly
  rather than relabeling the literal `χ` — see `EQUATION_MAPPING.md`.
- **`paper1608/plots/*.m`**: entire figure-generation pipeline predates the
  Issue I–P audit and its figure numbering does not match the real paper
  (only Fig. 2 happens to line up). Guarded with a hard error in
  `generate_all_paper_figures.m` to prevent accidental misuse. Needs a full
  rewrite against a real Phase C dataset (planned as a post-Phase-C step,
  not before — there's no data to test the rewrite against yet).
- **τ_max, R, B, δc, δa**: none are given numeric values by the paper; all
  are project-chosen placeholders (see `final_parameter_table.md`).
- **inverse_lambda_eps** (Issue P.1b v3; round-4 audit fixed a wording
  inconsistency here — state both numbers explicitly, they are DIFFERENT
  quantities, not two measurements of the same thing): default 1e-6 is
  fine for closed-loop convergence and physical-state figures, but a
  documented, non-trivial choice for any FUTURE figure that quantitatively
  plots `tau_cmd` or the moment-channel `tau_act`, across eps in
  {1e-8..1e-5}:
    - `tau_cmd` trajectory-level relative spread: **5.4%**
    - `tau_act` moment-channel trajectory-level relative spread: **33.0%**
      (P.1b v3's committed metric — max-minus-min across eps, divided by
      the max, computed over the FULL per-timestep trajectory matrix)
    - `tau_act` moment-channel RUN-LEVEL maximum: **21.2 → 25.7 Nm**
      across eps (a single peak value per run, not a trajectory spread —
      report this raw range, not as a percentage, to avoid conflating it
      with the trajectory-level metric above)
  Treat eps as an assumption in any of these scenarios, not a free
  numerical-safety detail.

## Last verified commit

(update this line at each checkpoint push)
`2290fa6` — **Phase C 100s production run COMPLETE.** E_chi converges
16.0 -> ~0.003-0.015 by t~7.5s and stays there through t=100s (genuine
long-horizon stability, not a short transient). All structural checks
pass. Evidence: `phase_c_result_t100.mat` / `phase_c_manifest_t100.mat`
/ `phase_c_analysis_t100.mat` / `phase_c_production_console.txt`. Next
milestone: plot pipeline rewrite (Figs. 2,3,6,7,8,9) against this real
dataset. Issue M/K and Figs.4-5 remain provisional, unaffected by this
run.

(Prior: `1281d58` — Phase C.0 Gate CLOSED after 7 GPT review rounds.
`b204679` — round 5, which first flagged the diary-logging/
clean-tree-evidence nuance that round 6 above resolved by running
tests with output kept outside the repo entirely.)
