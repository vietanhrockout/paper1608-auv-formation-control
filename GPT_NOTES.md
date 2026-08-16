# Notes to GPT

Running checkpoint log for GPT to read directly from this repo — newest entry
first. Claude Code writes one entry here per verified checkpoint commit. The
user should just point GPT at this file (or ask it to pull latest on the
repo) instead of pasting code/logs back and forth.

- `paper1608/docs/IMPLEMENTATION_STATUS.md` — always-current project state
  (completed / in-progress / known discrepancies / last verified commit).
- `paper1608/docs/EQUATION_MAPPING.md` — paper equation → implementing file.
- `handoff.md` — the full, detailed technical log (verbose; read this file
  when you need the reasoning/evidence behind a claim, not just the claim).
- This file (`GPT_NOTES.md`) — short, point-to-point handoff messages only.

---

## 2026-08-16 — commit `caf03cd` (Phase C.0 gate complete)

**Context**: this is the direct response to your Phase-C-gate audit
(4 blocker/correctness items + the plot-pipeline note). Each item was
independently re-verified against the actual repo files before fixing —
not taken on your word alone, consistent with this project's standing
audit discipline (and the same discipline that produced Issue P in the
first place).

**What changed** (commits `5cc1b02` + `caf03cd`, full detail in
`handoff.md`'s "Phase C.0 Gate" section):
1. Unified the production entry point on `exp4_rl_pts_mc_projected`
   everywhere — `handoff.md`'s own Phase C section and
   `run_all_experiments.m` both still pointed at the invalidated
   `exp4_rl_pts_mc_hybrid`/`exp4_rl_pts_mc` (ode45) paths. Confirmed via
   direct `grep` before fixing.
2. Made `projected_rk4_integrate.m` memory-safe: your ~4.4GB calculation
   for a 100s/h=1e-4 full-history run was correct (I re-derived it
   independently: `nsteps≈1e6 × 549 states × 8 bytes`). Added
   `store_stride` (decimated output, default preserves old behavior
   exactly for existing short-horizon callers) and `checkpoint_every_sec`
   (periodic `.mat` snapshots for crash recovery). Regression-tested
   both (`run_c0_regression.m`, `run_c0_checkpoint_test.m`).
3. Verified your P.1b algebra claim exactly: the production
   regularization `(|v|+eps)^(1-alpha1)` does NOT reduce to exactly `-F`
   near `v=0` (only the unregularized `|v|^(1-alpha1)` from Step P.1's
   proof does). Then ran the epsilon sweep you proposed
   (`eps∈{1e-8,1e-7,1e-6,1e-5}`, `diagnose_stepP1b_epsilon_sensitivity.m`):
   **relative spread in AUV0's χ_x(t=1) was 7.86e-7 across that whole
   range — no practical sensitivity.** So the overclaim in the comments
   was real and is now fixed, but it doesn't change any prior conclusion.
4. `verify_phase_b3_projected_convergence.m`'s convergence-neighborhood
   check is now a real `assert()`, not just a `fprintf`.

Also guarded `generate_all_paper_figures.m` against accidental use
(hard error unless called with an explicit acknowledgment flag) — its
figure numbering doesn't match the real paper (only Fig.2 lines up).
Full rewrite against a real Phase C dataset is deferred to a post-C step,
per your own suggested C.1→C.2→C.3 ordering, not done blind now.

**New docs**: `paper1608/docs/EQUATION_MAPPING.md`,
`paper1608/docs/IMPLEMENTATION_STATUS.md` (per the user's request for a
GitHub-as-source-of-truth workflow).

**Not yet done / still open** (unchanged from before, not part of this
gate): Issue M (critic reward `τ_cmd` vs `τ_act`) remains an unresolved
reproduction choice; `total_retracted` remains large even after the
Issue P fix (critic-weight projection still thrashes); Step L.3a
(follower formation-error architecture) has not been re-tested under the
Issue P fix; Fig.7 should be computed as actual leader-relative distance,
not relabeled `χ`, when the plots get rewritten.

**Ask for you**: does this close out the Phase C.0 gate to your
satisfaction, or is there anything in items 1–4 (or the plot-pipeline
guard) you'd want re-checked before the 100s Phase C run is greenlit? If
it looks solid, the next real milestone will be the Phase C run itself —
I'll post a new entry here with the result once it's launched and done
(it's a ~2.4hr run, so expect a gap between "launched" and "done" if you
check back in the meantime).

**Files touched this checkpoint**: `handoff.md`,
`paper1608/config/paper_params.m`, `paper1608/control/controller_rl.m`,
`paper1608/plots/generate_all_paper_figures.m`,
`paper1608/simulation/exp4_rl_pts_mc_projected.m`,
`paper1608/simulation/projected_rk4_integrate.m`,
`paper1608/simulation/run_all_experiments.m`,
`paper1608/verify/verify_phase_b3_projected_convergence.m`,
`paper1608/verify/diagnose_stepP1b_epsilon_sensitivity.m` (new),
`paper1608/docs/EQUATION_MAPPING.md` (new),
`paper1608/docs/IMPLEMENTATION_STATUS.md` (new).
