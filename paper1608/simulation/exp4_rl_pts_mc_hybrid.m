function res = exp4_rl_pts_mc_hybrid(t_final, t_hot, h_hot, params, sat_cfg, cfg)
% EXP4_RL_PTS_MC_HYBRID Hybrid Projected-RK4 / ode45 integrator for Paper
% 1608's closed-loop RL PT-SMC system (Step K.5).
%
% Rationale (see docs/HANDOFF.md Issue K / Issue N / Step K.5):
%   - Issue L/M: the raw command scale tau_cmd ~ O(10^7 N) and the
%     resulting critic reward/gradient scale are REAL, paper-faithful
%     behavior (matches Fig. 4's O(10^8) cost-to-go), not a bug.
%   - Issue N: raising the NN weight projection bounds delta_c/delta_a
%     does NOT fix ode45's stiffness -- the stall is intrinsic to the
%     magnitude of the critic ODE's RHS during the fast initial
%     transient, independent of delta_c/delta_a.
%   - Step K.4 validated a fixed-step, per-stage-projected RK4 stepper
%     that keeps ||Wc||<=delta_c, ||Wa||<=delta_a exactly through this
%     transient.
%
% This function integrates the first t_hot seconds with the validated
% projected_rk4_integrate stepper (fixed step h_hot), then splices the
% resulting endpoint state into a standard ode45 call (production
% tolerances, matching exp4_rl_pts_mc.m) for the remaining
% [t_hot, t_final] interval, where the dynamics are expected to be smooth
% once the formation errors have passed through their fast initial
% convergence window (Step L.3b: ~45-48 ms) and the critic weights have
% saturated onto the projection boundary.
%
% NO change to rhs_3auv_rl, controller_rl, or any paper-equation file.
% This is purely a numerical-integration strategy change, analogous in
% spirit to switching solvers/tolerances for a stiff ODE.

    if nargin < 1 || isempty(t_final)
        t_final = 15.0;
    end
    if nargin < 2 || isempty(t_hot)
        t_hot = 0.15;
    end
    if nargin < 3 || isempty(h_hot)
        h_hot = 1e-6;
    end
    if nargin < 4 || isempty(params)
        params = simulation_params();
    end
    if nargin < 5 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end

    assert(t_hot < t_final, 'exp4_rl_pts_mc_hybrid: t_hot must be < t_final.');

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);

    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    %% Phase 1: hot-phase Projected RK4
    fprintf('exp4_rl_pts_mc_hybrid: hot phase [0, %.4f]s, h=%.2e ...\n', t_hot, h_hot);
    [t_hot_vec, X_hot_mat, hot_stats] = projected_rk4_integrate(t_hot, h_hot, X0, params, sat_cfg, cfg);
    fprintf('exp4_rl_pts_mc_hybrid: hot phase done, %d steps, %.1fs wall, max retraction=%.3e\n', ...
        hot_stats.nsteps, hot_stats.elapsed, hot_stats.max_retraction);

    X_hot_end = X_hot_mat(end,:).';
    assert(~any(isnan(X_hot_end)) && ~any(isinf(X_hot_end)), ...
        'exp4_rl_pts_mc_hybrid: hot-phase endpoint contains NaN/Inf.');

    %% Phase 2: standard ode45 for the remainder
    tspan_cold = linspace(t_hot, t_final, max(2, round(300*(t_final-t_hot)/t_final)));
    options = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 5e-2);

    fprintf('exp4_rl_pts_mc_hybrid: cold phase [%.4f, %.2f]s via ode45 ...\n', t_hot, t_final);
    tic;
    [t_cold, X_cold] = ode45(@(t, X) rhs_3auv_rl(t, X, params, sat_cfg, cfg), tspan_cold, X_hot_end, options);
    elapsed_cold = toc;
    fprintf('exp4_rl_pts_mc_hybrid: cold phase done, %d points, %.1fs wall.\n', numel(t_cold), elapsed_cold);

    %% Combine (thin the hot-phase history to keep output size reasonable)
    hot_stride = max(1, floor(numel(t_hot_vec)/300));
    hot_idx = 1:hot_stride:numel(t_hot_vec)-1; % drop last hot point (== first cold point)

    t_out = [t_hot_vec(hot_idx); t_cold];
    X_out = [X_hot_mat(hot_idx,:); X_cold];

    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC_Hybrid';
    res.hot_stats = hot_stats;
    res.t_hot = t_hot;
    res.h_hot = h_hot;
end
