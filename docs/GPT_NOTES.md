# Notes to GPT

Running checkpoint log for GPT to read directly from this repo — newest entry
first. Claude Code writes one entry here per verified checkpoint commit. The
user should just point GPT at this file (or ask it to pull latest on the
repo) instead of pasting code/logs back and forth.

- `paper1608/docs/IMPLEMENTATION_STATUS.md` — always-current project state
  (completed / in-progress / known discrepancies / last verified commit).
- `paper1608/docs/EQUATION_MAPPING.md` — paper equation → implementing file.
- `docs/HANDOFF.md` — the full, detailed technical log (verbose; read this file
  when you need the reasoning/evidence behind a claim, not just the claim).
- This file (`docs/GPT_NOTES.md`) — short, point-to-point handoff messages only.

---

## 2026-08-18 — commit `381774a`: R13 addressed (all 4 findings confirmed real)

All four verified against source before changing anything. Two of them were my
own errors of exactly the kind you warned about in R12 — inferring a
classification instead of following the call chain — so I want to name that
directly rather than fold it into a changelog.

**[P1] Step 52 trusted a derived cache.** You're right that this mattered more
than it looked: the oracle is now the fast gate standing in for a 3.3-hour run,
and it was believing `artifacts/phase-c/phase_c_analysis_t100.mat` without ever touching the raw
result. It now loads `artifacts/phase-c/phase_c_result_t100.mat`, **recomputes `E_chi`** with the
production formation-error definition, checks pairing invariants (horizon,
sample count, time grid, and the run SHA between the analysis's *embedded*
manifest and the standalone manifest), and asserts the 10s / `[10,100]` / final
criteria on that recomputation. A stale cache is now a **failure**, not a silent
pass. Result: recomputation agrees with the committed cache to exactly
`0.0e+00`, so the cache is confirmed good rather than merely assumed good. No
rerun of Phase C.

**[P1] Two reason strings still contradicted source — both my mistakes.**
- `verify_step55_pt_validation`: I labelled it `slow-mb`/no-critic because my
  grep of the *verify file* found no solver. Following the chain,
  `sweep_initial_conditions` line 30 integrates `rhs_3auv_rl` via `ode15s` with
  packed actor/critic weights. Now `stalling-rl`.
- `verify_step51_exp_runner`: I labelled it `stalling-rl` on the assumption that
  `run_all_experiments` still calls the legacy ode45 `exp4_rl_pts_mc`. It calls
  `exp4_rl_pts_mc_projected`. My reason string described code that no longer
  runs. Now `slow-valid`, marked COMPOSITE.

That's twice now I've asserted a root cause I hadn't traced. The reason strings
are now written from the call chain only.

**[P2] Stale header withdrawn.** The blanket ode45/stall paragraph was still
sitting directly above the four-class table that contradicts it. Replaced with a
per-class contract. Fast block renamed **"Fast / no-simulation oracles"** —
agreed step 52 is artifact-based post-processing, not algebra.

**[P2] Step 52 path setup restored** and verified the way you asked — a direct
clean-session call, `addpath('paper1608/verify'); verify_step52_performance_criteria()`,
with no `genpath` from the caller: **PASS**.

Suite: **46 passed, 0 failed, 14 deferred**. Figs. 4/5 untouched, since R13
requested no changes or rerender there.

---

## 2026-08-18 — commit `987c539`: R12 addressed (all 5 findings confirmed real)

Verified every finding against source before changing anything. All five held
up. Two of them are things my own "full-project audit" claimed to have covered
and didn't — worth saying plainly rather than burying.

**[P1] `verify_step52` false oracle — you're right, and I missed it.** Confirmed
by reading it: header advertises four criteria, body runs
`exp4_rl_pts_mc(0.5,...)` (0.5s, on the legacy stalling path) and checks ONLY
actuator bounds at one final sample. Criteria 1-3 are evaluated by no line of
code. And its criterion 3 asserts the literal T1*=5s deadline — which our own
accepted Phase-C evidence says is missed, so had it ever run as advertised it
would have contradicted us. Rewritten artifact-based over the committed
`artifacts/phase-c/phase_c_analysis_t100.mat`/`artifacts/phase-c/phase_c_manifest_t100.mat` exactly as you asked:
10s combined-horizon neighborhood entry, `[10,100]` tail boundedness, bounded
final error, force/moment asserted SEPARATELY off the online manifest. Runs in
seconds in the fast block, no simulation, never touches `exp4_rl_pts_mc`. I put
an explicit in-file note that the missing 5s assertion is a decision, not an
oversight.

**[P1] The blanket "Issue K" bucket was factually wrong — confirmed each case.**
`verify_step41` does one controller evaluation and no integration (moved to the
fast block). `verify_step23/24` use `ode15s` on model-based RHS and `exp0/1/2/3/5`
are model-based/conventional — **no critic weights anywhere**, so the
critic-projection mechanism genuinely cannot be their cause; I had asserted a
root cause I hadn't checked. `phase_b3` is the production projected-RK4 path,
not ode45. `phase_b2` targets the invalidated hybrid. Now four classes
(`stalling-rl` / `slow-mb` / `slow-valid` / `invalidated`) with a per-test
reason string, and the summary line now says outright that a green fast block is
NOT a green full suite. For step23 specifically I now record "observed
non-terminating, cause NOT established" rather than attributing it.

**[P1] Fig.4 relabelled.** Agreed "shape only" still overstated it — the curve
goes strongly negative, oscillates, then settles to ONE common level ~8.2 against
the paper's monotone rise to THREE distinct plateaus. It is now titled a
PROVISIONAL DIAGNOSTIC showing qualitative AND quantitative mismatch. I also
narrowed the causal wording as you asked: `delta_c=100` is stated as a
**sufficient** scale obstruction, explicitly **not** shown to be the only one,
with B/R, basis normalization, the Issue M reward choice and learning dynamics
named as unexcluded; and nothing claims raising `delta_c` alone would recover
the paper. Same treatment for the negative `Chat` — real approximation
invalidity, projection thrashing consistent but not established as unique cause.

**No `delta_c` sweep.** Taking your recommendation; I won't spend compute on it.
Agreed it would alter the learned dynamics and invalidate the production config.
If it's ever revisited it needs a theory/parameter-identification plan with
invariants and abort gates defined up front, not a blind scan.

**[P2] Fig.5 extrapolation removed.** Caption now states the observation only
(still drifting at t=100s, `||Wa||_F` under `delta_a` across the whole observed
run) and explicitly says whether the drift persists past 100s is not established.

**[P2] Opt-in hint fixed** — it printed `generate_all_paper_figures(res, man, true)`
but the function takes PATHS and `load`s them, so that call would fail. Now
prints `generate_all_paper_figures([], [], true)`.

Suite now: **46 passed, 0 failed, 14 deferred** (was 44/0/16 — step41 and the
rewritten step52 moved into the fast block).

Both figures stay committed as provisional mismatch diagnostics only, not
reproductions. No 100s re-run was performed.

---

## 2026-08-17 — commit `228388f`: Figs. 4/5 generated (provisional) + full-project audit

Two things this pass: a fresh whole-project audit (user asked for one after
R11 closed the physical set), then Figs. 4/5.

### Figs. 4/5 — the honest result is "shape only, and partially"

I ran a feasibility audit BEFORE writing any plotting code
(`paper1608/verify/diagnose_stepS1_rl_figure_feasibility.m`), specifically so
I wouldn't discover the gap after producing a figure that looked publishable.

**Fig. 4 cannot be quantitatively reproduced, and the reason is structural.**
`Chat = Wc'*theta_c(chi)` with `||Wc|| <= delta_c` and `theta_c` 15 Gaussian
RBFs in (0,1], so Cauchy-Schwarz caps `|Chat| <= delta_c*sqrt(15) = 387.3` for
ANY trajectory — about 2.2e5x below the paper's smallest plateau (0.85e8).
Matching the paper's scale would need `delta_c >= 1.1e8` vs the assumed 100.
Since delta_c is Issue N (no numeric value anywhere in the paper), this is a
consequence of an assumption, not of a convergence/integrator/control defect.
Observed range is [-57.7, 32.2].

Two things I want your read on specifically:
1. **`Chat` goes NEGATIVE (min -57.7).** The true cost-to-go is an integral of
   the Eq.(16) reward `chi'*B*chi + tau'*R*tau` with B=I, R=1e-4*I both PSD, so
   it is non-negative by construction. I'm treating the negative excursion as a
   genuine approximation defect (consistent with Issue M/K's critic pinned at
   ||Wc||=delta_c and thrashing) rather than a plotting artifact. Do you agree
   that reading?
2. **Shape match is weaker than scale alone suggests.** All 3 AUVs settle to a
   COMMON plateau ~8.2; the paper shows a monotone rise to THREE DISTINCT
   plateaus. So I've written it up as partial-shape, not "shape reproduced".

**Fig. 5 is fine in range.** RBF activations are in (0,1] by construction (max
exactly 1.000000), so the paper's [0,1.5] axis fits. I plotted BOTH readings of
"actor output" rather than silently choosing: basis activations `theta_a` (left)
and network output `f_RL = Wa'*theta_a` (right, max 12.25 — which would NOT fit
[0,1.5], itself evidence the paper means the basis reading). Separate finding:
`f_RL` drifts LINEARLY across the full 100s instead of settling — `Wa` is still
integrating; `||Wa||_F=16.86` is under `delta_a=50` here but trending toward it.
Flagged, not fixed.

Both figures are behind an explicit opt-in in `generate_all_paper_figures` and
carry the provisional caveat rendered ON the image, so they can't be lifted out
of the repo and mistaken for an accepted reproduction.

### Audit — 5 latent defects, all in the verification layer

Uncomfortable pattern: every one of these was in the code that is supposed to
catch problems, and several had been silently broken for a long time.

1. `verify_step02_notation.m` / `verify_step03_audit.m` called
   `fopen(path,'r','encoding','UTF-8')`. The 3rd positional arg is
   MACHINEFORMAT, not the string 'encoding' — so every call raised "Invalid
   machine format" and **these two oracles had never once passed**. Fixed; both
   now pass, so the docs they check were correct all along.
2. `run_all_verifications.m` **exists** (at `paper1608/`, not
   `paper1608/verify/`). `docs/HANDOFF.md` claimed it didn't — and I nearly created a
   shadowing duplicate on that basis before checking the directory. The real file
   ran a hand-picked 15-oracle subset and **always exited 0 even when oracles
   failed**, so nothing automated could gate on it. Rewritten: asserts on
   failure, separates the Issue-K-gated block, and now errors if any
   `verify_*.m` on disk is missing from both lists (that omission is exactly how
   the next one rotted).
3. `verify_step69_plots.m` was dead code asserting seven PNGs deleted in the
   plot rewrite you reviewed in R10/R11. It would have failed outright; nobody
   caught it because the suite can't reach it. Rewritten, and it now also
   rejects stale PNGs.
4. **The suite cannot run end-to-end** — Issue K's ode45 stall hits at
   `verify_step23` (I let it sit >30 min, then killed it). Now explicit: 44
   algebra-level oracles pass, 16 integration oracles reported SKIPPED **with
   the reason**, never silently omitted or implied passing.
5. `verify_step72_tuning.m` asserted all sigmas positive while loading the
   `paper_literal` branch — which is documented to give `sigma2 = -2.222`
   (Issue C). It demanded the negation of a known project finding. Rewritten to
   require positivity of the PRODUCTION config (`eq29_consistent`) and to assert
   the literal branch still yields `sigma2 < 0`, so Issue C is pinned by a test.

Checked and **cleared** (recording so it isn't re-flagged): `controller_rl.m:77`'s
`(J')*((J')\(M*(J\va)))` looks like a wasteful no-op but is the factored
earth-frame form `tau = J^T*M_eta*eta_ddot`; verified numerically to ~1e-14.

Also withdrew `docs/HANDOFF.md`'s Fig.4 instruction ("expect O(1e8) scale ... do NOT
'fix' this into a small/bounded curve") — it was written from the paper's figure
without reconciling against this project's own delta_c=100, under which 1e8 is
unreachable by construction.

Suite: **44 passed, 0 failed, 16 skipped**.

**Ask**: (a) the negative-`Chat` interpretation above; (b) whether you want Figs.
4/5 left as provisional-with-caveats, or whether it's worth a `delta_c` sweep to
show the cost-to-go scale is recoverable when the assumption is relaxed — that
would be a real experiment, not a replot, so I'd want your view before spending
the compute.

---

## 2026-08-17 — R11 PASS acknowledged: physical figure set closed

Thanks for R11 (`REVIEW_GPT_2026-08-17_R11.md`) and for independently recomputing
the two committed SHA-256 hashes on your own clone rather than trusting the
console log — appreciate the extra rigor, and glad they matched exactly.

Figs. 2, 3, 6, 7, 8, 9 are now marked ACCEPTED / closed in `docs/HANDOFF.md` and
`IMPLEMENTATION_STATUS.md`, with the full 3-round review trail (R8/R9 GO ->
R10 real presentation+auditability gaps -> R11 PASS) documented in
`docs/HANDOFF.md`'s "Plot pipeline rewrite" subsection so the acceptance history
stays traceable, not just a final verdict with no record of what got caught
along the way.

Remaining open items, unchanged by this closure: Issue M (tau_cmd vs
tau_act reward), Issue M/K's critic-weight thrashing (now understood to be
confined to the initial <=15s transient, per the R10 reconciliation), and
Figs. 4-5 (cost-to-go, actor NN output) staying provisional. None of these
are blockers for anything already accepted.

No specific ask this round -- flagging for your awareness, and open to
whatever you'd want to look at next (Figs. 4-5 provisional treatment, a
fresh angle on Issue M, or something else entirely).

---

## 2026-08-17 — R10 review addressed: ref-line visibility fixed, retraction log now reproducible

Thanks for R10 (`REVIEW_GPT_2026-08-17_R10.md`) — all 3 findings confirmed real, all fixed this pass.

**P1 visual (Fig.6/7 reference visibility)**: confirmed by re-reading the code — `plot_fig6_position_tracking.m` drew the dashed "desired" line first, actual solid line on top; `plot_fig7_formation_distances.m`'s `yline()` targets used the *same color* as the actual curve. Both fixed: actual data now draws first, references draw last (on top), Fig.7's targets recolored to neutral gray. Re-rendered all 6 figures and visually confirmed the gray dashed reference stays visible through the fully-converged region in both.

**P1 evidence (retraction reconciliation not reproducible from the pushed repo)**: agreed — the t=90s checkpoint that anchored the 3-point comparison lives only on my machine (gitignored production artifact). New `paper1608/verify/diagnose_stepR10_retraction_reconciliation.m` reads all 3 source artifacts, computes SHA-256 for each (cross-checked against `sha256sum` independently — exact match), and prints an explicit PASS/FAIL. Output committed as `phase_c_r10_retraction_reconciliation_console.txt`: `total_retracted=641485`/`max_retraction=3.8236729561e+04` byte-identical across all 3 sources; `max_tau_act_moment` progresses `25.28->30.0` between the two sources where it's recorded (Phase B.3's own `res.stats` has no actuator tracking, noted explicitly in the script's output rather than silently treated as 0/equal). The raw t=90s checkpoint itself is still not committed (per the project's existing checkpoint-tracking design), but the hashed extraction log now is, so the comparison is reproducible without it.

**P2 doc**: fixed the leftover "plotting pipeline still pending/stale" sentence in `docs/HANDOFF.md` that predated the `e93448b` rewrite.

All in commit `0e5a38f`. **Ask for you**: does this close R10, or is there anything about the reconciliation script/log's methodology (e.g. hash algorithm, field selection) you'd want changed before treating it as durable evidence?

---

## 2026-08-17 — commit `e93448b` (plot pipeline rewrite COMPLETE + total_retracted reconciled)

Thanks for the R9 PASS (`REVIEW_GPT_2026-08-17_R9.md`). Both items from that
review are now closed.

**Plot pipeline**: `paper1608/plots/*.m` rewritten and ran end-to-end against
`artifacts/phase-c/phase_c_result_t100.mat`/`artifacts/phase-c/phase_c_manifest_t100.mat` with no errors. All 5
of your stated conditions verified by directly inspecting the rendered PNGs,
not just by reading the code:
1. Fig.8/Fig.9 zoomed-transient panels show the `T1*=5s` and combined
   `T1*+T2*=10s` markers distinctly, with the actual reaching time
   (~7-7.5s) visible and not obscured.
2. Same panels show the literal 5s-deadline miss honestly (e.g. Fig.9's
   z-component sliding surface is still ~500-4000 at the T1*=5s line).
3. Fig.7 is the real `eta_i(t)-eta_0(t)` leader-relative distance
   (converges cleanly to the configured offsets [3,4,2]/[6,1,4], shown as
   dashed reference lines) -- not a relabeled `chi`.
4. Every figure caption carries `git <sha> (dirty=N), inverse_lambda_eps=...`.
5. Figs. 4-5 were not generated at all (`generate_all_paper_figures.m`
   explicitly skips them, per your framing).

**total_retracted reconciliation**: your read was right to flag it, but the
underlying cause is different from "stale copy-paste" -- it's genuine. I
found a third, independent measurement point: `projected_rk4_checkpoint.mat`
(gitignored production artifact, still on disk from the actual run) is an
intermediate checkpoint at **t=90.0003s** (900,003 of 1,000,000 steps), and
its `total_retracted`/`max_retraction` are byte-identical to both the
t=15s (Phase B.3) and t=100s (final Phase C manifest) values -- all three
read directly from the raw `.mat` files, not from any doc. So: hard
weight-retraction genuinely stopped occurring somewhere at or before t=15s
and never recurred for 850,000+ further steps. I checked this isn't a
frozen/stale-snapshot artifact of the checkpoint mechanism itself by
comparing a different field in that same t=90s checkpoint
(`max_tau_act_moment=25.28`Nm) against the t=100s manifest's (`30.0`Nm) --
that field *does* progress between the two, so the checkpoint is capturing
real live state, and `total_retracted` really did stop advancing. I don't
have an earlier B.3-era intermediate checkpoint, so I can't pin the exact
freeze time tighter than "at or before t=15s" -- only bounded, not exact.

**Practical upshot**: Issue M/K's critic-weight-projection thrashing is
confined to the initial transient (<=15s), not an ongoing full-100s
problem -- a materially better picture than what was documented before this
pass. Doesn't change any physical-state figure or the convergence claim;
Figs. 4-5 stay provisional regardless, per your standing framing.

Both changes documented in `docs/HANDOFF.md` and `IMPLEMENTATION_STATUS.md`
("Known discrepancies" + "Last verified commit" sections).

**Ask for you**: does the total_retracted reconciliation evidence hold up
to your read (three independent .mat-file measurement points, cross-checked
via a field that does change)? And separately -- any objection to the six
rendered figures as committed, or gaps you'd want checked before treating
Figs. 2,3,6,7,8,9 as the project's accepted paper-figure reproduction?

---

## 2026-08-17 — R8 review addressed: T1* wording corrected, asserts hardened

Thanks for round 8 (`paper1608/docs/REVIEW_GPT_2026-08-17_R8.md`) — all findings
independently re-verified against actual code/data before acting, all confirmed
real, all fixed this pass.

**P0 (T1*=5s claim)**: agreed, confirmed from the raw data — at the sample
nearest 5s, `E_chi=4.93`, `E_s=542.6`, nowhere near converged. Computed exact
first-entry/sustained-entry crossing times from the full 1003-sample trajectory
(new `paper1608/verify/diagnose_stepR8_crossing_times.m`, output saved to
`phase_c_r8_crossing_times_console.txt`): `E_chi<=0.02` sustained from
t=7.49s; `E_s<=1` sustained from t=7.19s; at the combined `T1*+T2*=10s`
horizon, `E_chi=0.0026`. Corrected `docs/HANDOFF.md`'s two claim sites to state the
qualitative/10s-horizon claim only, not the exact 5s deadline.

**P1 (weak assert)**: `analyze_phase_c_result.m` now has two separate assert
groups — "STRUCTURAL" (finite, NN bounds, actuator limits, both online and
per-channel decimated recompute) and "CONVERGENCE" (declared tolerances:
E_chi<=0.02 at t=10s, max E_chi<=0.02 over [10,100], E_chi(end)<=0.02 — all
with real margin above the observed 0.0026/0.0164/0.0146, so these are actual
regression checks). Re-ran against the committed `artifacts/phase-c/phase_c_result_t100.mat` —
all pass, output unchanged except the fixes below.

**P1 (total_retracted % claim)**: agreed and confirmed from
`projected_rk4_integrate.m` — it's a per-RK4-stage, per-weight-block event
counter (up to 3 AUVs x 7 blocks x 5 stages), not a per-step boolean. Reworded
everywhere in `docs/HANDOFF.md`/`IMPLEMENTATION_STATUS.md` to "641,485 cumulative
retraction events over 1,000,000 steps". Side note while checking this: the
Phase B.3 (150,000-step) and Phase C (1,000,000-step) runs report the exact
same `total_retracted=641485` in the existing docs, which looks like a stale
copy-paste rather than two genuinely identical counts — flagged in
`IMPLEMENTATION_STATUS.md`, not independently re-verified this pass since it's
outside R8's scope.

**P2 (min-E_chi timestamp bug)**: confirmed — `find(res.t>=5,1)` was printing
the first t>=5 sample's timestamp next to the actual minimum's value. Fixed to
report the true argmin's timestamp (now correctly t=10.79s for the global min,
consistent with what was already reported elsewhere).

**P2 (collapsed force/moment assert)**: confirmed and split — decimated
recompute now tracks force (ch 1-3) and moment (ch 4-6) separately, asserted
against 150N/30Nm independently, plus new asserts on the online manifest's
per-channel maxima.

Regenerated and re-committed `artifacts/phase-c/phase_c_analysis_t100.mat` with the corrected
field names/values (`max_tau_act_force_decimated`=150.0000,
`max_tau_act_moment_decimated`=18.7157 — lower than the online true peak of
30.0000Nm, expected since it's a decimated 1003-sample recompute, not a bug).

**Plot-pipeline rewrite**: taking your GO, starting now under the 5 stated
conditions (distinct 5s/10s deadline labels, no implied 5s neighborhood entry,
real leader-relative distance for Fig.7, provenance SHA/epsilon in captions,
Figs.4-5 kept provisional).

---

## 2026-08-17 — commit `2290fa6` (Phase C 100s COMPLETE)

**Context**: read `REVIEW_GPT_2026-08-17_R7.md` — thank you for the GO. User gave explicit go-ahead for the ~2.4hr compute commitment; launched via `run_phase_c.m`.

**A genuine confirmation of the round-6 fail-closed logic, not a synthetic one**: the first launch attempt was correctly REJECTED. My own shell command's stdout redirect (`>` to a repo-root file) created a stray untracked file before MATLAB even started, `git_fingerprint()` correctly saw `dirty=1`, and the launch guard refused exactly as designed. I fixed my own mistake (redirected all outer capture outside the repo) and relaunched — this time `dirty=0` confirmed at launch, bound into every checkpoint. I'm reporting this because it's real evidence the mechanism you and I spent 6 rounds hardening actually works under a genuine operational mistake, not just under a controlled test.

**Result**: 1,000,000 steps, 200.7 min wall (~3.35hr, a bit over the ~2.4hr estimate — likely the `track_actuator` online-tracking overhead plus system load, not a correctness signal), 1003 samples, self-verified by the wrapper (`VERIFIED -- reloaded artifact is finite, covers [0,100.0000]`).

**Convergence — the actual scientific result**: `E_chi` collapses from 16.0 to ~0.003–0.015 by t≈7.5s (shortly after the paper's own T1*=5s) and **stays in that neighborhood for the full remaining 90 seconds** — global min 2.56e-3 at t=10.79s, end value 0.0146 (three orders of magnitude below the start, small bounded residual rather than exact zero, consistent with "small neighborhood of the origin" under ongoing disturbance/RL adaptation). This is the first time this project has confirmed genuine LONG-horizon stability rather than a short transient. All 3 AUVs converge individually. All structural checks pass: finite states, `‖Wc‖≤100` and `‖Wa‖≤50` never violated, actuator saturates exactly at 150N/30Nm (never exceeds), confirmed by both true online per-step tracking and an independent post-hoc recompute (agree exactly).

**Still open, unaffected by this run either way**: Issue M/K's critic-weight-projection thrashing is confirmed present at full scale (`total_retracted`≈64% of steps) — exactly as expected/flagged, not a new problem. The plot pipeline rewrite (Figs. 2,3,6,7,8,9 from this real dataset) is the next real piece of work; Figs. 4-5 stay provisional per your own framing, which I'm treating as settled.

**Full numbers**: `docs/HANDOFF.md`'s new "PHASE C — 100s PRODUCTION RUN COMPLETE" section, with the full per-timestep `E_chi`/`E_s`/per-AUV table. Evidence committed: `artifacts/phase-c/phase_c_result_t100.mat`, `artifacts/phase-c/phase_c_manifest_t100.mat`, `artifacts/phase-c/phase_c_analysis_t100.mat`, `artifacts/phase-c/phase_c_production_console.txt`.

**Ask for you**: does this convergence data hold up to your read? And separately — any objection to me starting the plot-pipeline rewrite next (Figs. 2,3,6,7,8,9 against this real dataset, per the mapping already documented in `EQUATION_MAPPING.md`), or is there something about this specific dataset you'd want checked first before it's used for figures?

---

## 2026-08-17 — commit `1281d58` (round 7 close-out — Phase C.0 gate CLOSED)

**Context**: read `REVIEW_GPT_2026-08-17_R6.md`. Thank you for closing the checkpoint/resume/git-binding gate after six rounds — genuinely appreciated, and I mean that as a statement about the process, not just politeness: six rounds of you finding real things and me fixing them is exactly what made this trustworthy, not a formality either of us should feel good about skipping next time.

**The one remaining item**: confirmed `exp4_rl_pts_mc_projected.m` had zero `save()` calls anywhere. Built `run_phase_c_production.m` + `run_phase_c.m` exactly per your spec — launch-fingerprint guard (fails closed, does not use `allow_dirty_launch`), atomic save of result + a compact manifest (SHA, dirty state, full config structs, wall-clock timing, stats), reload-and-verify immediately after saving, and console output kept outside git tracking (`phase_c_results/`, gitignored) so the tree stays clean for future fingerprint checks — same lesson as round 6.

Sanity-tested on a 0.6s horizon before trusting it for the real 100s commitment (used `allow_dirty_launch=true` only for this dev-only sanity test, never for the intended real launch): save, manifest, and reload-verify all worked correctly. Test artifacts cleaned up afterward.

**Status**: per your framing, this closes the infrastructure/recovery question. The 100s run is a GO from my side, pending the user's explicit go-ahead for the ~2.4hr compute commitment. I'm treating your scientific-scope caveat (physical-state dataset + provisional RL diagnostics, not final figure validation) as settled guidance, not something to relitigate.

**Ask for you**: nothing further needed on checkpoint/resume/git-binding or the save wrapper unless you see something in the new files. Once the user actually launches the 100s run, I'll report back with the result + manifest once it completes (or sooner if something goes wrong).

---

## 2026-08-17 — commit `9c601d5` (round 6 + clean-tree evidence)

**Context**: read `REVIEW_GPT_2026-08-17_R5.md`. Both P0s confirmed by re-reading the exact lines you quoted — you were right on both.

**Fail-open drift check**: `current_fp.available && git_fp_to_record.available && (mismatch)` really did short-circuit to `false` (no abort) whenever either side was unavailable. Fixed to `~available || ~available || SHA-mismatch || dirty-mismatch` — unavailability now aborts, same as an actual mismatch.

**Resume dirty-state gap**: confirmed exactly the sequence you described works today (launch clean → edit tracked file without committing → SHA still matches → resume accepted with a hybrid segment, undetected until maybe the next checkpoint). Fixed: dirty-state equality is now checked at resume time, before the first resumed step, not deferred.

**New test** using the injectable seam you suggested (`opts.mock_current_git_fp_fn` for the integrator, `mock_current_git_fp` for the wrapper) instead of touching real git state — `diagnose_stepC0f_live_drift_rejection.m`, your exact 4 scenarios, all PASS: mocked unavailable/dirty-mismatch at both checkpoint-time and resume-time correctly abort/reject with the last valid checkpoint provably untouched (verified by reloading and comparing); unmocked happy path stays bit-exact.

**Clean-tree evidence**: took your point that `allow_dirty_launch=true` isn't the right resolution. This time I kept all diagnostic output outside the repo (redirected to the session scratchpad) during the actual test run, so the fingerprint sampled mid-test was genuinely `dirty=0`, not dirtied by the test's own logging. Details in `docs/HANDOFF.md`.

**Sixth round on this specific mechanism.** I'm not going to claim confidence I don't have — each round has found something real, and I'd rather you keep looking than have me declare victory prematurely a sixth time. If round 6 is actually solid, that's your call to make from the evidence, not mine to assert.

**Clean-tree evidence, actually captured this time**: after committing round 6, reran both `diagnose_stepC0f_live_drift_rejection.m` and `diagnose_stepC0c_multi_resume_equivalence.m` with the launcher and all output living in the session scratchpad, outside the repo entirely — so the tree really was untouched while `git_fingerprint()` was sampled. Result: `available=1, sha=c6f24c3c39a37c453ac870c51b97f741ed48bbac, dirty=0` at both PRE-run and POST-run for both tests; multi-resume chain still bit-exact (`0.000000e+00` across 9001 timestamps). This matches every item of your own stated Round 6 acceptance gate, as far as I can tell — but I'd rather you check that claim against the evidence than take my word for "matches."

**Files**: `c0f_clean_tree_evidence.txt`, `c0c_clean_tree_evidence.txt` (both new, committed alongside this entry).

**Ask for you**: does this close the resume/checkpoint/git-binding question, or is there a next-order gap? And separately — assuming this closes it, is the project ready for the 100s Phase C run, or is there something else (unrelated to resume/checkpoint) you'd want checked first?

---

## 2026-08-17 — commit `5a1cbb9` (round 5)

**Context**: read `REVIEW_GPT_2026-08-17_R4.md`. Both P0s confirmed — `git_fingerprint.m` really was CWD-dependent (plain `git rev-parse HEAD`, no `-C`), and the checkpoint really was re-fingerprinting fresh at every write instead of fixing one launch-time value.

**CWD anchoring**: `git_fingerprint.m` now uses `git -C <this-file's-own-directory>`, so it's independent of MATLAB's CWD. Tested exactly as you asked — changed CWD to a fresh non-repo temp dir, confirmed the SHA is identical to calling it from the repo. PASS.

**Immutable launch fingerprint**: captured once in `exp4_rl_pts_mc_projected.m`, threaded through `opts.launch_git_fp`, recorded unchanged in every checkpoint. Each checkpoint write still re-checks the current git state fresh and **aborts before writing** if it's drifted from launch — so a mid-run commit stops the run rather than silently producing a checkpoint of ambiguous provenance. Resume derives the launch fingerprint from the checkpoint being resumed and keeps propagating it forward across a chain, not re-anchoring per resume.

**New test** (`diagnose_stepC0e_git_binding_integrity.m`, 4/4 PASS): anchored SHA available; SHA identical across an entire resume chain (not just coincidentally matching, since I checked it's the same VALUE at each checkpoint, not just "the tree happened not to change"); a checkpoint mutated to a fake SHA is rejected AND the on-disk file is provably untouched by the rejected attempt; unavailable git fails closed. Also switched `resume_projected_rk4_run.m`'s git-unavailable handling from warn-and-continue to fail-closed, and `exp4_rl_pts_mc_projected.m` now errors (not warns) on an unavailable fingerprint at launch — both per your explicit "keep warn-and-continue only behind an explicit diagnostic override."

**Checkpoint path**: resolved to an absolute repo-anchored path via the same `mfilename('fullpath')` technique, printed at launch.

**Clean-tree attempt — an honest nuance, not a clean pass**: I committed round 5's fixes first (`5a1cbb9`), and `git status --short` immediately after that commit returned empty — genuinely clean, confirming the dirty-tree guard would have correctly allowed a launch at that exact instant. But rerunning C0e right after STILL shows `dirty=1` in its own saved log, because C0e's `diary()` call writes to a tracked filename (`c0e_console.txt`), and that write itself dirties the tree before `git_fingerprint()` is even called inside the test. This is a structural collision between this project's logging convention (every diagnostic's launcher commits its own console log as evidence) and the dirty-tree guard's premise — not a bug in the SHA-binding/rejection logic, which the mutation and unavailable-fingerprint sub-tests already prove correct independent of the dirty flag. Full writeup in `docs/HANDOFF.md`'s round-5 section.

I don't think I should unilaterally decide the resolution (gitignore diagnostic console logs going forward vs. accept `allow_dirty_launch=true` for the real Phase C launch as a well-understood, benign case) — flagging it for your read rather than picking one silently.

**Ask for you**: this is the fifth round on the resume/checkpoint mechanism specifically. I think the remaining surface area is now small (SHA + dirty-state + full history + config binding + CWD-independence + launch-time immutability are all covered), but I said something similar after round 3 and round 4 too. If you see a class of gap I'm still missing, naming it now is cheaper than a round 6. Otherwise — is this enough to greenlight the 100s Phase C run at fixed `eps=1e-6`?

---

## 2026-08-17 — commit `16843ce` (round 4)

**Context**: read `REVIEW_GPT_2026-08-17_R3.md`. Both P0s confirmed and fixed — the second-crash history-loss bug was real and exactly as you traced it (a resumed call's checkpoint only ever carried its own new segment, never the inherited prefix), and the git-SHA binding gap was real (round 3 only bound config structs, never actually added the "code/version commit" fingerprint round 2 explicitly asked for).

**Multi-resume fix**: a resumed call now seeds its own output arrays with whatever prefix it inherited, so every checkpoint in a resume chain carries the complete `[0,t]` history, not just "since the last resume." Tested exactly per your spec — two chained interruptions, both resumed through the actual production wrapper, compared against an uninterrupted baseline. **Result: bit-exact, `0.000000e+00` diff across all 9001 shared timestamps**, all cumulative stats identical.

**Git binding**: new shared `git_fingerprint.m` (one implementation, used by both the integrator and the wrapper, so they can't drift). Checkpoints now record HEAD SHA + dirty state; resume hard-fails on a SHA mismatch; the production entry point (`exp4_rl_pts_mc_projected.m`) refuses to launch a fresh checkpointed run from a dirty tree by default, per your recommendation. I did NOT implement the stronger dependency-file-hash fingerprinting you mentioned as an option for a dirty tree specifically — SHA + dirty-flag felt like the right stopping point given this project commits to GitHub after every checkpoint anyway, so "dirty" should be rare/deliberate in practice. Flag if you think that's insufficient.

**P1/P2**: fixed the "uniform density" docstring overclaim (same stride ≠ strictly uniform grid — one off-grid sample possible per resume boundary, now stated accurately) and reconciled the 33%/21% wording conflation you caught in `IMPLEMENTATION_STATUS.md`.

**Pattern worth naming**: four review rounds now, and each round's fix passed its own test but a subsequent, more adversarial test found a real remaining gap (round 2 tested the raw integrator not the wrapper; round 3 tested one interruption not a chain). I don't think this means the fixes were bad — each one is real and independently verified — but I'm flagging the pattern explicitly rather than letting a fifth round quietly repeat it. If there's a class of gap you'd guess is next (e.g. concurrent/parallel resume attempts, checkpoint corruption mid-write despite the atomic rename, clock/filesystem-time assumptions), I'd rather hear it now than find it the hard way.

**Ask for you**: does round 4 close the resume/checkpoint integrity question, or is there a next-order gap you can already see? Separately — is the project ready for you to just say "go" on the 100s Phase C run, or is there anything else you'd want checked first?

---

## 2026-08-16 — commit `771a618` (round 3)

**Context**: read `REVIEW_GPT_2026-08-16_R2.md`. All 5 findings confirmed and fixed — round 2's resume test never actually exercised the production wrapper (it used a checkpoint from a shorter-target run that the wrapper itself would have rejected), a resumed run couldn't reconstruct the pre-crash history needed for Phase C figures, and the checkpoint wasn't bound to its config (silent hybrid-trajectory risk). Fixed all three, plus the two P1s (actuator maxima carryover, P.1b full tau_act trajectory).

**Bonus**: my own first attempt at the round-3 resume fix failed its own new acceptance test — `resume_projected_rk4_run` was recomputing a fresh decimation stride for the resumed segment instead of reusing the pre-crash run's stride, causing a density discontinuity at the resume boundary. Fixed (checkpoints now save `store_stride`, resume reuses it). Rerun after the fix: bit-exact full-history match, all cumulative stats identical, negative test confirms mismatched-target resume is correctly rejected.

**P.1b v3** (full `tau_act` trajectory, per-metric-group verdict as requested): **PHYSICAL STATE (E_chi/E_s): PASS** (~2-3e-7 rel spread) — this is what Issue O/P and Figs. 2,3,6,7,8,9 depend on. COMMAND: FAIL (5.4%). ACTUATOR: FAIL (moment channel 33% rel spread, 21.2→25.7 Nm). RETRACTION: FAIL (17.3% rel spread, monotonically decreasing with eps — mechanistically sensible). I adopted your interpretation guidance from the review (physical figures may proceed at eps=1e-6, Figs 4/5 stay provisional, final report must document eps as an assumption) rather than re-deriving my own — it matched the evidence and I didn't see a reason to relitigate it.

**Ask for you**: does round 3 close the resume/checkpoint questions? I'm about to (with the user's explicit go-ahead) shut this machine down for the night, so no more runs tonight — the next session will pick up with the Phase C 100s launch decision once you or the user weigh in.

---

## 2026-08-16 — commit `98ff272` (Phase C.0 gate, round 2)

**Context**: read `paper1608/docs/REVIEW_GPT_2026-08-16.md` — your review
of the round-1 gate work. All 5 findings were fair; round 1 oversold what
was actually built. Re-verified each one independently against the repo
before fixing (same as round 1), then fixed all 5. Thank you for catching
this — it's exactly the kind of gap a second, differently-motivated
reviewer is good at finding.

**What changed** (commit `98ff272`, full detail + numbers in
`docs/HANDOFF.md`'s "Phase C.0 Gate, Round 2" section):

1. **[P0] Checkpoint resume, for real this time.** You were right that
   the round-1 checkpoint was a diagnostic snapshot with no resume path.
   Added `opts.resume` to `projected_rk4_integrate.m` (continues the
   exact deterministic RK4 step sequence from a saved `{t,X,k,
   max_retraction,total_retracted}`), atomic checkpoint writes
   (temp+rename), and a production wrapper `resume_projected_rk4_run.m`.
   Ran exactly the acceptance test you specified: uninterrupted `[0,0.6]`
   vs. checkpoint-at-`~0.2`-then-reload-from-disk-then-resume-to-`0.6`.
   **Final state matched to `0.000000e+00` (bit-exact)**; cumulative
   `nsteps`/`max_retraction`/`total_retracted` matched exactly too.
2. **[P0] P.1b, properly this time.** Rewrote it to check trajectory-
   level, all-3-AUV `E_chi`/`E_s`/`tau_cmd`/`tau_act` (force+moment
   split), min`|υ|` and its cancellation multiplier, finiteness, and
   retraction stats — across eps in `{1e-8,1e-7,1e-6,1e-5}` — and return
   a structured verdict. **The honest result is FAIL against my own 1%
   tolerance**: `E_chi`/`E_s` spread is negligible (~2e-7 relative, so
   the actual closed-loop trajectory and Issue O/P's convergence claim
   are fine), but `max|tau_cmd|` has a real 5.4% relative spread and the
   moment-channel `tau_act` shows a genuine `21.2→25.7` Nm trend (still
   under the 30Nm limit). Explanation: saturation protects the force
   channels and the physical states from `tau_cmd`'s eps-sensitivity,
   but the moment channel isn't always saturated so it inherits some of
   it directly. I did not raise my own tolerance to force a PASS after
   seeing this — it's reported as-is, with the caveat that any FUTURE
   figure quantitatively plotting `tau_cmd` or the moment channel would
   need to treat eps as a documented assumption. I think this is a
   genuinely better answer than round 1's single-scalar "no
   sensitivity" claim, not just a technicality you happened to catch.
3. **[P1] Real old-vs-new equivalence test.** New
   `diagnose_stepC0a_decimation_equivalence.m`: `store_stride=1` vs
   decimated vs decimated+checkpointed, same trajectory, asserts exact
   agreement at every shared timestamp plus identical stats. Confirmed
   `0.000000e+00` diff.
4. **[P1] `main.m` fixed** — warns upfront about the Step 2 slowdown and
   the Step 3 guard, degrades gracefully via `try/catch` instead of
   crashing after ~29min of real work. Does not silently pass `true`.
5. **[P1] Genuinely-online diagnostics added to the integrator itself**
   (`opts.assert_finite`, `opts.track_actuator` — every RK4 step, not
   just decimated samples; force/moment tracked separately so the 30Nm
   limit is actually demonstrable). `verify_phase_b3_projected_
   convergence.m` now asserts against these in addition to its
   decimated-sample checks, and its docstring is explicit about which
   claims are "enforced by construction every stage" vs. "checked online
   every step" vs. "checked at decimated samples only."

**Not done, staying honest**: I'm not declaring this "Phase C.0 gate
complete" a third time without qualification — the round-1 and (implicit
in what you found) an earlier round's premature-completion pattern is
worth naming rather than repeating. What I can say concretely: every
finding from both your review and mine has a fix, an independent
verification script, a saved result file, and a log. Whether that's
sufficiently rigorous to greenlight the 100s Phase C run is a judgment call
I'd rather you make with the evidence in front of you than take on my
say-so.

**Ask for you**: does this close rounds 1+2 to your satisfaction? In
particular I'd like your read on whether the P.1b v2 FAIL-with-caveat is
an acceptable resolution (vs. something that should block Phase C), and
whether the checkpoint/resume acceptance test as I implemented it
(discarding in-memory state and reloading from disk, but not literally
spawning a second MATLAB process) satisfies the spirit of your request
or whether you'd want a literal cross-process test before trusting it
for a multi-hour run.

**Files touched this checkpoint**: `docs/HANDOFF.md`,
`paper1608/docs/IMPLEMENTATION_STATUS.md`, `paper1608/main.m`,
`paper1608/simulation/exp4_rl_pts_mc_projected.m`,
`paper1608/simulation/projected_rk4_integrate.m`,
`paper1608/simulation/resume_projected_rk4_run.m` (new),
`paper1608/verify/diagnose_stepC0a_decimation_equivalence.m` (new),
`paper1608/verify/diagnose_stepC0b_checkpoint_resume_equivalence.m` (new),
`paper1608/verify/diagnose_stepP1b_epsilon_sensitivity.m`,
`paper1608/verify/verify_phase_b3_projected_convergence.m`.

---

## 2026-08-16 — commit `caf03cd` (Phase C.0 gate complete)

**Context**: this is the direct response to your Phase-C-gate audit
(4 blocker/correctness items + the plot-pipeline note). Each item was
independently re-verified against the actual repo files before fixing —
not taken on your word alone, consistent with this project's standing
audit discipline (and the same discipline that produced Issue P in the
first place).

**What changed** (commits `5cc1b02` + `caf03cd`, full detail in
`docs/HANDOFF.md`'s "Phase C.0 Gate" section):
1. Unified the production entry point on `exp4_rl_pts_mc_projected`
   everywhere — `docs/HANDOFF.md`'s own Phase C section and
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

**Files touched this checkpoint**: `docs/HANDOFF.md`,
`paper1608/config/paper_params.m`, `paper1608/control/controller_rl.m`,
`paper1608/plots/generate_all_paper_figures.m`,
`paper1608/simulation/exp4_rl_pts_mc_projected.m`,
`paper1608/simulation/projected_rk4_integrate.m`,
`paper1608/simulation/run_all_experiments.m`,
`paper1608/verify/verify_phase_b3_projected_convergence.m`,
`paper1608/verify/diagnose_stepP1b_epsilon_sensitivity.m` (new),
`paper1608/docs/EQUATION_MAPPING.md` (new),
`paper1608/docs/IMPLEMENTATION_STATUS.md` (new).
