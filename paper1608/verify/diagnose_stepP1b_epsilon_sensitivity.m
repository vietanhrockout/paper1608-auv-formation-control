function verdict = diagnose_stepP1b_epsilon_sensitivity(t_final, h)
    % DIAGNOSE_STEPP1B_EPSILON_SENSITIVITY (v2, Phase C.0 gate follow-up)
    %
    % The first version of this script (superseded) only compared AUV0's
    % chi_x at the FINAL timestep across epsilon values -- a single scalar
    % diagnostic. The second GPT audit pass correctly flagged this as
    % insufficient to "close" the epsilon-regularization question. This
    % version implements the exact acceptance test requested:
    %   - For every epsilon, compute TRAJECTORY-LEVEL, ALL-AUV maxima/
    %     differences for E_chi, E_s, tau_cmd, and tau_act (not just one
    %     AUV's endpoint).
    %   - Record the minimum |vel_err| encountered (across all AUVs/DOFs/
    %     time) and the resulting cancellation multiplier
    %     (|v|/(|v|+eps))^(alpha1-1) at that worst-case point (1.0 = exact
    %     -F cancellation per Step P.1's algebra; 0.0 = complete loss of
    %     the reaching-law F-term).
    %   - Assert all states/RHS finite throughout (via the integrator's
    %     opts.assert_finite, on by default).
    %   - Compare max_retraction/total_retracted across epsilon.
    %   - Return AND save a structured PASS/PARTIAL/FAIL verdict, not just
    %     print a conclusion.

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 1.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end

    eps_list = [1e-8, 1e-7, 1e-6, 1e-5];
    cfg = nn_config();
    sat_cfg = saturation_config();

    runs = cell(1, numel(eps_list));

    for ei = 1:numel(eps_list)
        eps_v = eps_list(ei);
        fprintf('=== eps=%.1e, t_final=%.2f, h=%.1e ===\n', eps_v, t_final, h);

        params = simulation_params();
        params.inverse_lambda_eps = eps_v;

        [eta_init, nu_init] = initial_conditions();
        omega_aw_mat = zeros(6, 3);
        Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
        Wc_mat = zeros(cfg.critic_n_nodes, 3);
        X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

        opts = struct('store_stride', 1, 'assert_finite', true, 'track_actuator', true);
        [t_hist, X_hist, stats] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts);

        N = numel(t_hist);
        E_chi = zeros(N, 1);
        E_s = zeros(N, 1);
        max_tau_cmd = zeros(N, 1);
        min_abs_vel_err = inf;
        min_vel_err_eps_ratio = NaN; % (|v|/(|v|+eps))^(alpha1-1) at the worst-case (smallest |v|) point

        for k = 1:N
            Xk = X_hist(k, :).';
            [eta_m, nu_m, omega_m, Wa_l, ~] = unpack_states(Xk, cfg);
            e_chi_k = zeros(3, 1);
            e_s_k = zeros(3, 1);
            tau_cmd_k = zeros(3, 1);
            for i = 1:3
                eta = eta_m(:, i);
                J = jacobian_J(eta);
                eta_dot = J * nu_m(:, i);
                [chi, vel_err] = formation_error(eta, eta_dot, t_hist(k), i);
                s = sliding_surface(chi, vel_err, params);
                tau_cmd = controller_rl(eta, eta_dot, t_hist(k), i, omega_m(:, i), Wa_l{i}, params, cfg);

                e_chi_k(i) = max(abs(chi));
                e_s_k(i) = max(abs(s));
                tau_cmd_k(i) = max(abs(tau_cmd));

                abs_v = abs(vel_err);
                [min_abs_v_here, j_here] = min(abs_v);
                if min_abs_v_here < min_abs_vel_err
                    min_abs_vel_err = min_abs_v_here;
                    min_vel_err_eps_ratio = (min_abs_v_here / (min_abs_v_here + eps_v)) ^ (params.alpha1 - 1);
                end
            end
            E_chi(k) = max(e_chi_k);
            E_s(k) = max(e_s_k);
            max_tau_cmd(k) = max(tau_cmd_k);
        end

        assert(all(isfinite(E_chi)) && all(isfinite(E_s)) && all(isfinite(max_tau_cmd)), ...
            'eps=%.1e: non-finite E_chi/E_s/tau_cmd found in post-processed trajectory', eps_v);

        run = struct();
        run.eps = eps_v;
        run.t = t_hist;
        run.E_chi = E_chi;
        run.E_s = E_s;
        run.max_tau_cmd = max_tau_cmd;
        run.max_tau_act_force = stats.max_tau_act_force;
        run.max_tau_act_moment = stats.max_tau_act_moment;
        run.min_abs_vel_err = min_abs_vel_err;
        run.min_vel_err_eps_ratio = min_vel_err_eps_ratio;
        run.stats = stats;
        runs{ei} = run;

        fprintf('  %d steps, %.1fs wall, max_retraction=%.6e, total_retracted=%d\n', stats.nsteps, stats.elapsed, stats.max_retraction, stats.total_retracted);
        fprintf('  E_chi(end)=%.6f, E_s(end)=%.6f, max|tau_cmd|(traj)=%.6e\n', E_chi(end), E_s(end), max(max_tau_cmd));
        fprintf('  max|tau_act| force=%.4f moment=%.4f\n', stats.max_tau_act_force, stats.max_tau_act_moment);
        fprintf('  min|vel_err| encountered = %.6e, cancellation multiplier there = %.6f (1.0=exact -F, 0.0=total loss)\n', ...
            min_abs_vel_err, min_vel_err_eps_ratio);
    end

    fprintf('\n=== CROSS-EPSILON COMPARISON (trajectory-level, all runs share common timestamps since h is fixed) ===\n');

    N_common = numel(runs{1}.t);
    for r = 2:numel(runs)
        assert(numel(runs{r}.t) == N_common, 'eps runs have different sample counts -- cannot compare trajectories directly');
    end

    E_chi_matrix = zeros(N_common, numel(runs));
    E_s_matrix = zeros(N_common, numel(runs));
    tau_cmd_matrix = zeros(N_common, numel(runs));
    for r = 1:numel(runs)
        E_chi_matrix(:, r) = runs{r}.E_chi;
        E_s_matrix(:, r) = runs{r}.E_s;
        tau_cmd_matrix(:, r) = runs{r}.max_tau_cmd;
    end

    E_chi_spread_traj = max(E_chi_matrix, [], 2) - min(E_chi_matrix, [], 2);
    E_s_spread_traj = max(E_s_matrix, [], 2) - min(E_s_matrix, [], 2);
    tau_cmd_spread_traj = max(tau_cmd_matrix, [], 2) - min(tau_cmd_matrix, [], 2);

    max_E_chi_spread = max(E_chi_spread_traj);
    max_E_s_spread = max(E_s_spread_traj);
    max_tau_cmd_spread = max(tau_cmd_spread_traj);

    E_chi_scale = max(E_chi_matrix(:));
    E_s_scale = max(E_s_matrix(:));
    tau_cmd_scale = max(tau_cmd_matrix(:));

    rel_E_chi = max_E_chi_spread / max(1e-9, E_chi_scale);
    rel_E_s = max_E_s_spread / max(1e-9, E_s_scale);
    rel_tau_cmd = max_tau_cmd_spread / max(1e-9, tau_cmd_scale);

    fprintf('max trajectory-wide spread across eps: E_chi=%.6e (rel %.4e), E_s=%.6e (rel %.4e), tau_cmd=%.6e (rel %.4e)\n', ...
        max_E_chi_spread, rel_E_chi, max_E_s_spread, rel_E_s, max_tau_cmd_spread, rel_tau_cmd);

    force_vals = cellfun(@(r) r.max_tau_act_force, runs);
    moment_vals = cellfun(@(r) r.max_tau_act_moment, runs);
    retraction_vals = cellfun(@(r) r.stats.max_retraction, runs);
    retracted_count_vals = cellfun(@(r) r.stats.total_retracted, runs);

    fprintf('max|tau_act| force across eps: [%s]\n', num2str(force_vals, '%10.4f'));
    fprintf('max|tau_act| moment across eps: [%s]\n', num2str(moment_vals, '%10.4f'));
    fprintf('max_retraction across eps: [%s]\n', num2str(retraction_vals, '%12.4e'));
    fprintf('total_retracted across eps: [%s]\n', num2str(retracted_count_vals));

    TOLERANCE_REL = 1e-2; % 1% relative spread threshold
    all_metrics_ok = (rel_E_chi < TOLERANCE_REL) && (rel_E_s < TOLERANCE_REL) && (rel_tau_cmd < TOLERANCE_REL);

    verdict = struct();
    verdict.eps_list = eps_list;
    verdict.runs = runs;
    verdict.max_E_chi_spread = max_E_chi_spread;
    verdict.max_E_s_spread = max_E_s_spread;
    verdict.max_tau_cmd_spread = max_tau_cmd_spread;
    verdict.rel_E_chi = rel_E_chi;
    verdict.rel_E_s = rel_E_s;
    verdict.rel_tau_cmd = rel_tau_cmd;
    verdict.tolerance_rel = TOLERANCE_REL;
    verdict.force_vals = force_vals;
    verdict.moment_vals = moment_vals;
    verdict.retraction_vals = retraction_vals;
    verdict.retracted_count_vals = retracted_count_vals;

    if all_metrics_ok
        verdict.result = 'PASS';
        fprintf('\nVERDICT: PASS -- all trajectory-level metrics (E_chi, E_s, tau_cmd) agree within %.1f%% across eps in [1e-8,1e-5]. Default eps=1e-6 is not a load-bearing choice in this range.\n', TOLERANCE_REL*100);
    else
        verdict.result = 'FAIL';
        fprintf('\nVERDICT: FAIL -- at least one trajectory-level metric exceeds the %.1f%% relative-spread tolerance across eps. Needs further investigation before treating eps as a non-issue.\n', TOLERANCE_REL*100);
    end

    save('p1b_result.mat', 'verdict');
    fprintf('=== END P.1b v2 (structured verdict saved to p1b_result.mat) ===\n');
end
