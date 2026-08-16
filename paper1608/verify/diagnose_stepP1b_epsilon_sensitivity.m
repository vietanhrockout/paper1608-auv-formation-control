function verdict = diagnose_stepP1b_epsilon_sensitivity(t_final, h)
    % DIAGNOSE_STEPP1B_EPSILON_SENSITIVITY (v2, Phase C.0 gate follow-up)
    %
    % The first version of this script (superseded) only compared AUV0's
    % chi_x at the FINAL timestep across epsilon values -- a single scalar
    % diagnostic. The second GPT audit pass (round 1) correctly flagged
    % this as insufficient. v2 added trajectory-level E_chi/E_s/tau_cmd
    % but, per round-2 audit, still only compared a single run-level
    % max|tau_act| scalar (via stats.max_tau_act_force/moment), not the
    % full tau_act(t) trajectory -- this version (v3) closes that gap by
    % also computing and comparing the per-timestep max|tau_act| force/
    % moment trajectories, with their own explicit tolerance/verdict
    % (kept separate from E_chi/E_s/tau_cmd rather than lumped in, since
    % round 2 noted retraction/actuator metrics deserve their own
    % explicit treatment, not just inclusion in one blended verdict).
    % Full acceptance test:
    %   - For every epsilon, compute TRAJECTORY-LEVEL, ALL-AUV maxima/
    %     differences for E_chi, E_s, tau_cmd, AND tau_act (force/moment
    %     trajectories, not just one run-level max each).
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
        max_tau_act_force_traj = zeros(N, 1);
        max_tau_act_moment_traj = zeros(N, 1);
        min_abs_vel_err = inf;
        min_vel_err_eps_ratio = NaN; % (|v|/(|v|+eps))^(alpha1-1) at the worst-case (smallest |v|) point

        for k = 1:N
            Xk = X_hist(k, :).';
            [eta_m, nu_m, omega_m, Wa_l, ~] = unpack_states(Xk, cfg);
            e_chi_k = zeros(3, 1);
            e_s_k = zeros(3, 1);
            tau_cmd_k = zeros(3, 1);
            tau_act_force_k = zeros(3, 1);
            tau_act_moment_k = zeros(3, 1);
            for i = 1:3
                eta = eta_m(:, i);
                J = jacobian_J(eta);
                eta_dot = J * nu_m(:, i);
                [chi, vel_err] = formation_error(eta, eta_dot, t_hist(k), i);
                s = sliding_surface(chi, vel_err, params);
                tau_cmd = controller_rl(eta, eta_dot, t_hist(k), i, omega_m(:, i), Wa_l{i}, params, cfg);
                tau_act = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);

                e_chi_k(i) = max(abs(chi));
                e_s_k(i) = max(abs(s));
                tau_cmd_k(i) = max(abs(tau_cmd));
                tau_act_force_k(i) = max(abs(tau_act(1:3)));
                tau_act_moment_k(i) = max(abs(tau_act(4:6)));

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
            max_tau_act_force_traj(k) = max(tau_act_force_k);
            max_tau_act_moment_traj(k) = max(tau_act_moment_k);
        end

        assert(all(isfinite(E_chi)) && all(isfinite(E_s)) && all(isfinite(max_tau_cmd)) ...
            && all(isfinite(max_tau_act_force_traj)) && all(isfinite(max_tau_act_moment_traj)), ...
            'eps=%.1e: non-finite E_chi/E_s/tau_cmd/tau_act found in post-processed trajectory', eps_v);

        % Cross-check the trajectory-derived force/moment maxima against
        % the integrator's own true-online (every-step, not just
        % decimated) tracking -- they should match exactly here since
        % this script uses store_stride=1 (every step IS a decimated
        % sample), and this also validates the two independent
        % computations (post-hoc recompute vs. online integrator) agree.
        assert(abs(max(max_tau_act_force_traj) - stats.max_tau_act_force) < 1e-9, ...
            'eps=%.1e: post-hoc max tau_act force (%.6f) disagrees with online-tracked value (%.6f)', ...
            eps_v, max(max_tau_act_force_traj), stats.max_tau_act_force);
        assert(abs(max(max_tau_act_moment_traj) - stats.max_tau_act_moment) < 1e-9, ...
            'eps=%.1e: post-hoc max tau_act moment (%.6f) disagrees with online-tracked value (%.6f)', ...
            eps_v, max(max_tau_act_moment_traj), stats.max_tau_act_moment);

        run = struct();
        run.eps = eps_v;
        run.t = t_hist;
        run.E_chi = E_chi;
        run.E_s = E_s;
        run.max_tau_cmd = max_tau_cmd;
        run.tau_act_force_traj = max_tau_act_force_traj;
        run.tau_act_moment_traj = max_tau_act_moment_traj;
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
    tau_act_force_matrix = zeros(N_common, numel(runs));
    tau_act_moment_matrix = zeros(N_common, numel(runs));
    for r = 1:numel(runs)
        E_chi_matrix(:, r) = runs{r}.E_chi;
        E_s_matrix(:, r) = runs{r}.E_s;
        tau_cmd_matrix(:, r) = runs{r}.max_tau_cmd;
        tau_act_force_matrix(:, r) = runs{r}.tau_act_force_traj;
        tau_act_moment_matrix(:, r) = runs{r}.tau_act_moment_traj;
    end

    [max_E_chi_spread, rel_E_chi] = local_traj_spread(E_chi_matrix);
    [max_E_s_spread, rel_E_s] = local_traj_spread(E_s_matrix);
    [max_tau_cmd_spread, rel_tau_cmd] = local_traj_spread(tau_cmd_matrix);
    [max_tau_act_force_spread, rel_tau_act_force] = local_traj_spread(tau_act_force_matrix);
    [max_tau_act_moment_spread, rel_tau_act_moment] = local_traj_spread(tau_act_moment_matrix);

    fprintf('max trajectory-wide spread across eps:\n');
    fprintf('  E_chi=%.6e (rel %.4e), E_s=%.6e (rel %.4e)\n', max_E_chi_spread, rel_E_chi, max_E_s_spread, rel_E_s);
    fprintf('  tau_cmd=%.6e (rel %.4e)\n', max_tau_cmd_spread, rel_tau_cmd);
    fprintf('  tau_act_force=%.6e (rel %.4e), tau_act_moment=%.6e (rel %.4e)\n', ...
        max_tau_act_force_spread, rel_tau_act_force, max_tau_act_moment_spread, rel_tau_act_moment);

    retraction_vals = cellfun(@(r) r.stats.max_retraction, runs);
    retracted_count_vals = cellfun(@(r) r.stats.total_retracted, runs);
    retraction_spread_rel = (max(retraction_vals) - min(retraction_vals)) / max(1e-9, max(retraction_vals));

    fprintf('max_retraction across eps: [%s] (rel spread %.4e)\n', num2str(retraction_vals, '%12.4e'), retraction_spread_rel);
    fprintf('total_retracted across eps: [%s]\n', num2str(retracted_count_vals));

    TOLERANCE_REL = 1e-2; % 1% relative spread threshold

    % Round-2 audit fix: separate verdicts per metric GROUP, not one
    % blended pass/fail -- physical-state trajectory fidelity is a
    % different claim than command/actuator-level fidelity, and each
    % should be judged (and cited) on its own terms.
    physical_ok = (rel_E_chi < TOLERANCE_REL) && (rel_E_s < TOLERANCE_REL);
    command_ok = (rel_tau_cmd < TOLERANCE_REL);
    actuator_ok = (rel_tau_act_force < TOLERANCE_REL) && (rel_tau_act_moment < TOLERANCE_REL);
    retraction_ok = (retraction_spread_rel < TOLERANCE_REL);

    verdict = struct();
    verdict.eps_list = eps_list;
    verdict.runs = runs;
    verdict.rel_E_chi = rel_E_chi;
    verdict.rel_E_s = rel_E_s;
    verdict.rel_tau_cmd = rel_tau_cmd;
    verdict.rel_tau_act_force = rel_tau_act_force;
    verdict.rel_tau_act_moment = rel_tau_act_moment;
    verdict.retraction_spread_rel = retraction_spread_rel;
    verdict.tolerance_rel = TOLERANCE_REL;
    verdict.retraction_vals = retraction_vals;
    verdict.retracted_count_vals = retracted_count_vals;
    verdict.physical_result = local_pass_fail(physical_ok);
    verdict.command_result = local_pass_fail(command_ok);
    verdict.actuator_result = local_pass_fail(actuator_ok);
    verdict.retraction_result = local_pass_fail(retraction_ok);
    verdict.result = local_pass_fail(physical_ok && command_ok && actuator_ok && retraction_ok); % overall, kept for backward compat

    fprintf('\nVERDICT (per metric group, %.1f%% relative-spread tolerance):\n', TOLERANCE_REL*100);
    fprintf('  PHYSICAL STATE (E_chi, E_s):        %s -- this is what Issue O/P convergence and Figs.2,3,6,7,8,9 depend on\n', verdict.physical_result);
    fprintf('  COMMAND (tau_cmd, unsaturated):     %s\n', verdict.command_result);
    fprintf('  ACTUATOR (tau_act force/moment):    %s\n', verdict.actuator_result);
    fprintf('  RETRACTION (max_retraction):        %s\n', verdict.retraction_result);
    fprintf('  OVERALL:                             %s\n', verdict.result);
    if physical_ok && ~(command_ok && actuator_ok)
        fprintf('\nINTERPRETATION: the physical closed-loop trajectory (and hence Issue O/P''s convergence claim) is NOT meaningfully sensitive to eps in this range, even though the unsaturated command and/or actuator channels are. eps=1e-6 remains a safe default for Figs.2,3,6,7,8,9. A future figure quantitatively plotting tau_cmd or the moment channel must treat eps as a documented assumption.\n');
    end

    save('p1b_result.mat', 'verdict');
    fprintf('=== END P.1b v3 (structured, per-metric-group verdict saved to p1b_result.mat) ===\n');
end

function s = local_pass_fail(cond)
    if cond
        s = 'PASS';
    else
        s = 'FAIL';
    end
end

function [max_spread, rel_spread] = local_traj_spread(M)
    spread_traj = max(M, [], 2) - min(M, [], 2);
    max_spread = max(spread_traj);
    rel_spread = max_spread / max(1e-9, max(M(:)));
end
