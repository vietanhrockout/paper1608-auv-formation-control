# Independent Review — R8 Corrections

**Reviewer:** GPT/Codex  
**Claude baseline reviewed:** `64af5ab`  
**Verdict:** **PASS. All R8 findings are addressed; proceed with the physical-figure pipeline rewrite under the previously stated conditions.**

## Confirmed

- The exact `T1*=5 s` reaching claim has been withdrawn. The documentation now distinguishes the 5 s reaching deadline from the combined `T1*+T2*=10 s` horizon.
- Crossing times are calculated from all 1,003 stored samples rather than inferred from the sparse handoff table:
  - `E_chi <= 0.02` is sustained from `t=7.4925 s`;
  - `E_s <= 1` is sustained from `t=7.1928 s`;
  - at the sample nearest 10 s, `E_chi=0.002583` and `E_s=0.008188`.
- Structural and scientific-convergence verdicts are now separated.
- Convergence assertions enforce neighborhood entry by the combined horizon, bounded behavior over `[10,100]`, and a bounded final error using declared tolerances.
- Force and moment channels are recomputed and asserted independently against `150 N` and `30 Nm`; online manifest maxima are also checked independently.
- The minimum-error timestamp bug is fixed.
- `total_retracted` is correctly described as cumulative per-stage/per-weight-block events, not a percentage of integration steps.

## Remaining known issue, not a plot-pipeline blocker

The identical documented `total_retracted=641,485` values for the 15 s Phase B.3 and 100 s Phase C runs are suspicious and already flagged as potentially stale. Do not use that count quantitatively in Figs. 4–5 or the final RL interpretation until the two MAT artifacts are independently read and the statistic is reconciled. This does not affect the accepted physical-state trajectory or Figs. 2, 3, 6, 7, 8, and 9.

## Decision

Proceed with the physical plots. Preserve the following review constraints:

1. distinguish the 5 s and 10 s markers;
2. show the observed miss of the literal 5 s reaching deadline honestly;
3. derive Fig. 7 from actual leader-relative quantities;
4. include source SHA and `inverse_lambda_eps=1e-6` in provenance metadata;
5. keep Figs. 4–5 provisional.

No MATLAB implementation change is requested by this review.
