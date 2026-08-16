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

- **P.1b v2** result: structured verdict is **FAIL** against a 1%
  relative-spread tolerance across eps in {1e-8..1e-5} — but the failure
  is entirely in `max|tau_cmd|` (5.4% relative spread, the UNSATURATED
  command) and the moment-channel `tau_act` (21.2→25.7 Nm trend, still
  under the 30Nm limit). `E_chi`/`E_s` (the actual physical trajectory)
  show negligible spread (~2-3e-7 relative). Mechanistically expected:
  eps regularizes a near-singularity in the unsaturated command; force
  channels are protected by saturation (pegged at 150N regardless of
  eps), the moment channel isn't always saturated so it inherits some of
  tau_cmd's eps-sensitivity directly. **Conclusion**: eps=1e-6 remains
  fine for closed-loop convergence and physical-state figures (2,3,6,7,
  8,9); a FUTURE figure that quantitatively plots tau_cmd or the moment
  channel would need to treat eps as a documented assumption, like
  tau_max/R/B/delta_c/delta_a. See `handoff.md`'s Phase C.0 Gate Round 2
  section for full numbers.

## In progress

None — Phase C.0 Gate rounds 1 and 2 are both fully addressed with
verified evidence for every finding. Next milestone is the Phase C
(100s) run itself, pending explicit user go-ahead (real ~2.4hr compute
commitment).

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
- **inverse_lambda_eps** (Issue P.1b v2): default 1e-6 is fine for
  closed-loop convergence and physical-state figures, but a documented,
  non-trivial choice for any FUTURE figure that quantitatively plots
  `tau_cmd` or the moment-channel `tau_act` (5.4% / up-to-21% relative
  sensitivity respectively across eps in {1e-8..1e-5}) — treat it as an
  assumption in that scenario, not a free numerical-safety detail.

## Last verified commit

(update this line at each checkpoint push)
`98ff272` — Phase C.0 gate round 2 complete (real checkpoint resume,
bit-exact equivalence tests, online diagnostics, honest P.1b v2 result
with a documented eps-sensitivity caveat for tau_cmd/moment-channel
figures). Phase C (100s run) awaiting explicit user go-ahead — not yet
launched.
