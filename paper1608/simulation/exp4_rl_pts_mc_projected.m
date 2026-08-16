function res = exp4_rl_pts_mc_projected(t_final, h, params, sat_cfg, cfg, n_target, allow_dirty_launch)
% EXP4_RL_PTS_MC_PROJECTED Production simulation entry point using the
% fixed-step, per-stage-projected RK4 integrator for the ENTIRE horizon
% (Step K.7).
%
% Supersedes both exp4_rl_pts_mc.m (plain ode45 -- fails, Issue K/L) and
% exp4_rl_pts_mc_hybrid.m (hot-phase Projected RK4 + ode45 cold phase --
% invalidated by Step K.5/K.6: the ode45/ode15s stiffness at the critic-
% weight projection boundary is PERSISTENT, not a brief initial
% transient, so there is no non-stiff "cold phase" to hand off to).
%
% Step K.7 found that coarsening the fixed step from h=1e-6 (Step K.4/
% K.5, ~100-125 steps/s, infeasible for 15-100s horizons) to h=1e-4
% (100x coarser) keeps the exact structural bound ||Wc||<=delta_c (the
% per-stage retraction is O(1) and exact regardless of step size) while
% running ~100x faster. Step P.4 re-validated h=1e-4 accuracy for the
% physical states under the current (Issue P-fixed) dynamics: relative
% max|d_eta|=3.2e-7, max|d_nu|=1.7e-5 vs h=1e-5 (far tighter than the
% stale K.7-era numbers this comment used to cite, which were measured
% under the old frozen/non-convergent dynamics and are no longer valid --
% see handoff.md's Phase C.0 Gate section). Critic weights remain
% step-size-sensitive (max|d_Wc|~11% of delta_c) -- expected, tied to the
% still-open Issue M/K critic-projection-thrashing question.
%
% Default h=1e-4 gives ~22min for a 15s run, ~2.4hr for a 100s run.
%
% MEMORY SAFETY (Phase C.0 gate fix): the underlying integrator no longer
% allocates a full per-step history. At h=1e-4/100s (1e6 steps x 549
% states x 8 bytes ~= 4.4GB), storing every step would risk exhausting
% RAM; n_target (default 1001) controls how many samples are actually
% kept, computed as a store_stride passed into projected_rk4_integrate
% BEFORE integration starts, so the oversized array is never allocated.
% A periodic checkpoint (every 10s of simulated time, see
% checkpoint_every_sec below) is also written ATOMICALLY (temp file +
% rename) for crash/kill recovery -- resumable via
% resume_projected_rk4_run.m (Phase C.0 gate follow-up: the original
% checkpoint was a diagnostic snapshot only; equivalence to an
% uninterrupted run is verified in
% paper1608/verify/diagnose_stepC0b_checkpoint_resume_equivalence.m).
% Online per-step finiteness assertion (opts.assert_finite) and
% per-channel (force/moment) actuator saturation tracking
% (opts.track_actuator) are both enabled for the production path.
%
% DIRTY-TREE LAUNCH GUARD (Phase C.0 gate round 3, GPT audit): checkpoints
% are now bound to the git commit SHA at write time (see
% projected_rk4_integrate.m/git_fingerprint.m), but a SHA alone doesn't
% pin down an uncommitted (dirty) working tree's exact state -- so this
% function refuses to LAUNCH a fresh checkpointed run from a dirty tree
% by default (a multi-hour Phase C run should be reproducible from its
% recorded SHA). Pass allow_dirty_launch=true only for deliberate
% diagnostic/development runs where that guarantee doesn't matter.

    if nargin < 1 || isempty(t_final)
        t_final = 15.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end
    if nargin < 3 || isempty(params)
        params = simulation_params();
    end
    if nargin < 4 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    if nargin < 5 || isempty(cfg)
        cfg = nn_config();
    end
    if nargin < 6 || isempty(n_target)
        n_target = 1001;
    end
    if nargin < 7 || isempty(allow_dirty_launch)
        allow_dirty_launch = false;
    end

    git_fp = git_fingerprint();
    if ~git_fp.available
        warning('exp4_rl_pts_mc_projected: git unavailable -- launching without a verifiable source-code fingerprint for this run''s checkpoints.');
    elseif git_fp.dirty && ~allow_dirty_launch
        error(['exp4_rl_pts_mc_projected: refusing to launch a checkpointed production run from a DIRTY git tree ' ...
               '(uncommitted changes) -- a multi-hour run should be reproducible from its recorded commit SHA. ' ...
               'Commit your changes first, or pass allow_dirty_launch=true for a deliberate diagnostic/dev run.']);
    elseif git_fp.dirty
        warning('exp4_rl_pts_mc_projected: launching from a DIRTY git tree with allow_dirty_launch=true -- this run''s exact source state is not fully reproducible from its SHA alone.');
    end

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);

    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    nsteps = ceil(t_final / h);
    store_stride = max(1, floor(nsteps / n_target));

    fprintf('exp4_rl_pts_mc_projected: integrating [0, %.4f]s at h=%.2e (%d steps, storing every %d-th step -> ~%d samples) ...\n', ...
        t_final, h, nsteps, store_stride, floor(nsteps/store_stride)+1);

    opts = struct();
    opts.store_stride = store_stride;
    opts.checkpoint_every_sec = 10;
    opts.checkpoint_path = 'projected_rk4_checkpoint.mat';
    opts.assert_finite = true;
    opts.track_actuator = true;

    [t_full, X_full, stats] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts);

    fprintf('exp4_rl_pts_mc_projected: done, %d steps, %.1fs wall, max_retraction=%.3e, %d stored samples\n', ...
        stats.nsteps, stats.elapsed, stats.max_retraction, numel(t_full));
    fprintf('exp4_rl_pts_mc_projected: max|tau_act| force=%.4f N (limit %.1f), moment=%.4f Nm (limit %.1f) -- tracked online at EVERY step, not just decimated samples\n', ...
        stats.max_tau_act_force, sat_cfg.force_max, stats.max_tau_act_moment, sat_cfg.moment_max);

    res = struct();
    res.t = t_full;
    res.X = X_full;
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC_Projected';
    res.h = h;
    res.stats = stats;
end
