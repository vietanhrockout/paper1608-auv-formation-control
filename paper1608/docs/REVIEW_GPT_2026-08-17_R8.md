# Independent Review — Phase C 100 s Result

**Reviewer:** GPT/Codex  
**Claude baseline reviewed:** `f91fdce` (Phase C result commit `2290fa6`)  
**Scope:** Production provenance, saved result/manifest, post-hoc analysis, and readiness for physical-figure generation.  
**Verdict:** **Dataset integrity PASS; sustained long-horizon physical convergence PASS; exact predefined-time interpretation requires correction before plotting/reporting.**

## Confirmed result integrity

- The production console records a clean launch at SHA `1d8e1f8f403ee791f13a292e236f3c2ae2dc834a`, `git_dirty=0`.
- The intended production configuration was used: `t_final=100`, `h=1e-4`, `n_target=1001`, proof-consistent unsigned inverse, `inverse_lambda_eps=1e-6`, and raw-command critic reward.
- The run completed 1,000,000 RK4 steps in 12,039 s and stored 1,003 samples.
- The durable wrapper reloaded the saved result and verified finiteness, `[0,100]` coverage, and sample count.
- Online every-step actuator statistics report force `150 N` and moment `30 Nm`, at but not above their respective limits.
- The committed MAT artifacts are MATLAB v5 files with timestamps consistent with the run/analysis sequence and plausible sizes for the stated trajectory/manifest/analysis payloads.

The production/recovery gate remains closed and no rerun is requested for artifact-integrity reasons.

## Scientific findings

### [P0 interpretation] Do not claim that the run reproduces the `T1*=5 s` reaching deadline

The committed table reports at the sample nearest 5 s:

```text
t = 4.995 s
E_chi = 4.934126
E_s   = 542.577353
```

The sliding variable is therefore nowhere near its eventual small neighborhood at `T1*=5 s`. It becomes small only between the 4.995 s and 7.492 s reported samples (`E_s=0.008537` at 7.492 s).

Both `T1*=5 s` and `T2*=5 s` are configured. The physical tracking error is small before the combined horizon `T1*+T2*=10 s`, so the evidence supports:

- sustained long-horizon convergence/stability;
- entry into a small tracking neighborhood before 10 s;
- qualitative agreement with the eventual small-neighborhood behavior.

It does **not** support an unqualified statement that the reaching phase meets `T1*=5 s`, nor a blanket claim that Theorems 1 and 2 are quantitatively reproduced. Update `docs/HANDOFF.md`/status language accordingly and show both the 5 s and 10 s deadlines in any relevant analysis.

Before final wording, calculate from the 1,003-sample trajectory the first entry time and sustained-entry time for explicitly declared thresholds for both `E_s` and `E_chi`. Do not infer the crossing time from only the sparse table shown in the handoff.

### [P1] The new analysis assertions are weaker than the reported conclusion

`analyze_phase_c_result.m` only asserts:

```matlab
E_chi(end) < E_chi(1)
```

That proves some decrease, not convergence to a small neighborhood or sustained convergence. A substantially poor trajectory could still pass “ALL STRUCTURAL ASSERTS.” Add separately labeled assertions/metrics for:

- tracking-neighborhood entry by the combined 10 s horizon;
- maximum `E_chi` over `[10,100]` against a declared tolerance;
- final `E_chi` against a declared tolerance;
- force maximum against `150 N` and moment maximum against `30 Nm` using the online manifest fields.

Keep structural validity and scientific convergence as separate verdict groups rather than one blended PASS.

### [P1] `total_retracted` is not a percentage of time steps

The statement “`total_retracted=641485` of 1,000,000 steps (~64%)” is not justified by the integrator's statistic. `total_retracted` accumulates retraction events across projected state blocks/RK4 stages; it is not a Boolean count of unique time steps containing at least one retraction. Earlier project documentation correctly described values greater than one event per step.

Report it as `641,485 cumulative retraction events over 1,000,000 integration steps` unless a separate unique-step counter is implemented. Remove the “64% of steps” interpretation from `docs/HANDOFF.md`, implementation status, and figure/report prose.

### [P2] Minor analysis-output corrections

- `min E_chi over [T1*,100]` currently prints the first timestamp satisfying `t>=5`, not the timestamp of that interval's minimum. Compute the indexed minimum within the subset.
- The decimated actuator assertion collapses force and moment into one scalar and only checks `<=150`; this cannot independently enforce the `30 Nm` moment limit. The online manifest already has the correct split and should be asserted directly.

## Plot-pipeline decision

**GO for rewriting physical Figs. 2, 3, 6, 7, 8, and 9 from this dataset**, with these conditions:

1. label the 5 s reaching deadline and 10 s combined deadline distinctly where relevant;
2. do not visually or textually imply `s` reached its neighborhood by 5 s if the data says otherwise;
3. for Fig. 7, compute actual leader-follower relative distance/error directly rather than relabeling the controller's virtual-reference `chi`;
4. preserve the dataset's provenance SHA and fixed epsilon in figure metadata/captions;
5. keep Figs. 4–5 provisional because the critic/reward issues remain unresolved.

## Decision

- **Production dataset:** accepted.
- **Long-horizon physical stability:** accepted.
- **Exact `T1*=5 s` reaching claim:** not reproduced by the reported data; wording must be corrected.
- **Physical plotting rewrite:** approved under the conditions above.

This review changes no Claude MATLAB implementation.
