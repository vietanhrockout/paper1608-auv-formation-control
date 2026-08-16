function res = exp4_rl_pts_mc_projected(t_final, h, params, sat_cfg, cfg)
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
% running ~100x faster, with a convergence check (h=1e-4 vs h=1e-5 over
% a 0.1s segment) showing negligible/small physical-state error
% (max|d_eta|=4.4e-4, max|d_nu|=1.37e-2 -- acceptable for figure
% reproduction).
%
% Default h=1e-4 gives ~22min for a 15s run, ~2.4hr for a 100s run.

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

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);

    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    fprintf('exp4_rl_pts_mc_projected: integrating [0, %.4f]s at h=%.2e (%d steps) ...\n', ...
        t_final, h, ceil(t_final/h));

    [t_full, X_full, stats] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg);

    fprintf('exp4_rl_pts_mc_projected: done, %d steps, %.1fs wall, max_retraction=%.3e\n', ...
        stats.nsteps, stats.elapsed, stats.max_retraction);

    % Thin the output history to a manageable size (matches exp4_rl_pts_mc.m's
    % ~301-point convention) while always keeping the first and last sample.
    n_target = 601;
    stride = max(1, floor(numel(t_full)/n_target));
    idx = [1:stride:numel(t_full)-1, numel(t_full)];

    res = struct();
    res.t = t_full(idx);
    res.X = X_full(idx,:);
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC_Projected';
    res.h = h;
    res.stats = stats;
end
