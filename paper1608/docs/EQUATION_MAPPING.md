# Equation Mapping

Paper: Guo, Xiao, Shen, Chen, Guo, Luo. "Reinforcement learning predefined-time
formation control for uncertain AUVs with disturbance and input saturation."
*Neurocomputing* 677 (2026) 133031.

Maps each paper equation to the file(s) implementing it. Verified against the
raw PDF text (`pdf_extracted_text.txt`, not just `equation.md`'s transcription)
wherever a discrepancy mattered — see `handoff.md`'s Issue P section for an
example where that distinction was load-bearing.

This complements, not replaces, `handoff.md` (the authoritative running log)
and `reproduction_matrix.md` (an older step/phase tracker using an unrelated
"Phase A–P" numbering — do not confuse its "Phase P" with `handoff.md`'s
"Issue P"; `reproduction_matrix.md` predates this session and is stale in
places, e.g. it still references `verify_step72`-era phase gates that were
superseded by the Issue O/P work below).

| Paper equation | What it defines | Implementation | Status |
|---|---|---|---|
| Eq. (1)–(2) | 6-DOF kinematics/dynamics: `η̇=J(η)ν`, `Mν̇+C(ν)ν+D(ν)ν+g(η)=J⁻ᵀ(τ+Δτ)+τ_L` | `model/jacobian_J.m`, `model/mass_matrix.m`, `model/coriolis_matrix.m`, `model/damping_matrix.m`, `model/restoring_force.m`, `model/auv_dynamics.m` | Verified (Phase B/C of old `reproduction_matrix.md` step tracker, `verify_step10`–`14`) |
| Eq. (2)–(3) | Actuator saturation `sat(τ_cmd)=τ_act`, `Δτ=τ_act-τ_cmd` | `math/sat_vector.m`, `config/saturation_config.m` | Verified; `τ_max=150N/30Nm` is **ASSUMED** (paper gives no numeric value) — see `docs/final_parameter_table.md` |
| Eq. (5) | Formation position error `χᵢ=ηᵢ-η_d0-η^l_0i` | `control/formation_error.m` | Verified literal (Step L.3a confirmed this is Candidate A / paper-literal; Candidate B tested, not adopted — see handoff.md) |
| Eq. (6) | Formation velocity error `υᵢ=η̇ᵢ-η̇_d0` | `control/formation_error.m` | Verified literal |
| Eq. (7) | True unknown drift `f_i` (used only for model-based baseline, not the model-free RL path) | `control/f_true_drift.m` | Verified, not used by production `rhs_3auv_rl.m` |
| Eq. (14) | RBF Gaussian basis / Critic value estimate `V̂ᵢ(Zᵢ)=ŵ_c^Tθ_c(χᵢ)` | `math/rbf_gaussian.m`, `nn/critic_basis.m`, `nn/critic_output.m` | Verified |
| Eq. (16) | Instantaneous reward `r(t)=χᵀBχ+τᵀRτ` | `control/strategic_utility.m` | `B=I₆`, `R=1e-4·I₆` **ASSUMED** (not paper-specified). `τ` argument mode controlled by `params.critic_reward_tau_mode` (Issue M — reopened/unresolved, see handoff.md) |
| Eq. (17) | Bellman residual `c_ei` | `nn/bellman_error.m` | Verified |
| Eq. (19) | Raw critic gradient-descent update | `nn/critic_update.m` | Verified |
| Eq. (20) | Critic weight parameter-projection operator | `nn/projection_operator.m`, `nn/critic_update.m` | Verified structurally; `δc=100` **ASSUMED** (Issue N — evidence against bound-size as primary stiffness cause, not fully closed) |
| Eq. (21) | Nonsingular predefined-time terminal sliding surface `sᵢ=L(χᵢ)χᵢ+sig^α1(υᵢ)`, gain `l_χij` | `control/sliding_surface.m`, `control/gain_matrix_L.m` | Verified |
| Eq. (22) | Reaching-law gain parameters `a1, a2` | `config/derived_params.m` | Verified (`a1=1.192474`, `a2=12.878722` for Table 1 params) |
| Eq. (23) | Sliding-surface derivative `ṡᵢ=L(χᵢ)υᵢ+L̃(χᵢ)υᵢ+α1Λ1υ̇ᵢ`, `Λ1=diag{|υij|^(α1-1)}` (UNSIGNED) | `control/matrix_Lambda1.m`, `control/gain_matrix_Ltilde.m` | Verified against raw PDF text — **central to Issue P** (see below) |
| Eq. (24) | `L̃(χᵢ)` derivative-gain matrix | `control/gain_matrix_Ltilde.m`, `control/matrix_Lambda1.m` | Verified |
| Eq. (25) | Model-based PT-SMC control law (uses true `f_i`) | `control/controller_model_based.m`, `control/pt_reaching_term.m` | Verified, reference/baseline only |
| Eq. (26) / (29) | Reaching-law gains `σ1, σ2` | `config/derived_params.m` (`params.sigma_mode`) | `'eq29_consistent'` is production default (literal Eq.26 gives negative σ2 — see Issue C in `assumptions_log.md`) |
| Eq. (30) | Anti-windup auxiliary state `ϖ̇ᵢ` | `control/antiwindup_rhs.m` | Verified |
| Eq. (31) | **Full proposed control law** `τᵢ=J^TMᵢ(...)` | `control/controller_rl.m` | Verified against raw PDF text term-by-term. Reaching-law `F`-term's `Λ1⁻¹` inverse mode controlled by `params.inverse_lambda_mode` (**Issue P** — literal `sig^(1-α1)(υ)` proven algebraically inconsistent with Eq.23's unsigned `Λ1`; production default switched to `'proof_consistent_unsigned'`, user-confirmed; see handoff.md). Regularization epsilon: `params.inverse_lambda_eps` (Issue P.1b, GPT audit) |
| Eq. (32) | Actor RBF basis / drift estimate `f_iRL` | `nn/actor_basis.m`, `nn/actor_output.m` | Verified |
| Eq. (34) | Actor estimation error `e_ai` | `nn/actor_error.m` | Verified |
| Eq. (37)–(38) | Actor weight update + projection | `nn/actor_update.m`, `nn/projection_operator.m` | Verified structurally; `δa=50` **ASSUMED** |
| Eq. (55) | Ocean current disturbance `τ_L(t)` | `model/ocean_disturbance.m` | Verified |
| Eq. (56) | Initial conditions `ηᵢ(0)` | `reference/initial_conditions.m` | Verified against PDF |
| Eq. (57) | Virtual leader reference trajectory `η_d0(t)`, formation offsets `η^l_0i` | `reference/reference_1608.m`, `reference/formation_offsets.m` | Verified against PDF |
| — (operator defs, no single eq. number) | `sig^a(x)=\|x\|^a·sgn(x)` signed-power operator | `math/sigpow.m`, `math/sigpow_negative.m` | Verified; used throughout, see Issue P for a case where its literal application (Eq.31) contradicts an unsigned quantity used elsewhere (Eq.23) |

## Closed-loop orchestration (not a single equation)

| Role | Implementation |
|---|---|
| Full 549-state ODE right-hand side (all 3 AUVs) | `simulation/rhs_3auv_rl.m` |
| State vector pack/unpack | `simulation/pack_states.m`, `simulation/unpack_states.m` |
| Production integrator (fixed-step, per-stage-projected RK4) | `simulation/projected_rk4_integrate.m` |
| Production entry point | `simulation/exp4_rl_pts_mc_projected.m` — **the only entry point that should be used**; `exp4_rl_pts_mc.m` (plain `ode45`) and `exp4_rl_pts_mc_hybrid.m` (hot/cold split) are both known-broken/invalidated, kept for history only |

## Known reproduction gaps / ambiguities (see `handoff.md` for full detail)

- `τ_max`, `R`, `B`, `δc`, `δa` are **not given numeric values by the paper** — all are project-chosen.
- Issue M: whether the Eq.(16) reward uses `τ_cmd` (raw) or `τ_act` (saturated) is unresolved as a reproduction choice (Fig.4 magnitude argument favors raw, but is itself conditioned on the assumed `R`).
- Step L.3a: whether follower `χᵢ` should use the virtual reference `η_d0` (paper-literal, Eq.5) or the actual leader `η₀` is a live reproduction-fidelity question for Fig. 7/8, independent of Issue P.
