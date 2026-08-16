function diagnose_stepP1b_epsilon_sensitivity(t_final, h)
    % DIAGNOSE_STEPP1B_EPSILON_SENSITIVITY
    % Issue P.1b (raised by a second independent audit, GPT, reviewing the
    % pushed repo on GitHub): Step P.1's pure-algebra proof that the
    % 'proof_consistent_unsigned' branch reduces the reaching-law F-term's
    % ds/dt contribution to exactly -F uses the UNREGULARIZED |v|^{1-alpha1}.
    % The PRODUCTION code in controller_rl.m regularizes near v=0 as
    % (|v|+eps)^{1-alpha1} to avoid a literal singularity -- this is only
    % an approximation of -F, exactly matching it only away from v=0 (the
    % coefficient (|v|/(|v|+eps))^{alpha1-1} -> 0, not 1, as v->0).
    %
    % This script checks whether closed-loop results (E_chi, E_s, max
    % |tau_cmd|) are sensitive to the choice of eps, by running the SAME
    % short closed-loop simulation (same ICs, same integrator, same
    % everything except params.inverse_lambda_eps) at eps in
    % {1e-8, 1e-7, 1e-6, 1e-5} and comparing the AUV0 trajectories.

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

    results = struct();

    for ei = 1:numel(eps_list)
        eps_v = eps_list(ei);
        field = sprintf('eps_%d', ei);

        params = simulation_params();
        params.inverse_lambda_eps = eps_v;

        fprintf('=== eps=%.1e, t_final=%.2f, h=%.1e ===\n', eps_v, t_final, h);

        [eta_init, nu_init] = initial_conditions();
        omega_aw_mat = zeros(6, 3);
        Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
        Wc_mat = zeros(cfg.critic_n_nodes, 3);
        X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

        [t_hist, X_hist, stats] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg);

        Xend = X_hist(end, :).';
        [eta_m, nu_m, omega_m, Wa_l, ~] = unpack_states(Xend, cfg);
        eta0 = eta_m(:, 1);
        J0 = jacobian_J(eta0);
        eta0_dot = J0 * nu_m(:, 1);
        [chi0, vel_err0] = formation_error(eta0, eta0_dot, t_hist(end), 1);
        s0 = sliding_surface(chi0, vel_err0, params);
        tau_cmd0 = controller_rl(eta0, eta0_dot, t_hist(end), 1, omega_m(:, 1), Wa_l{1}, params, cfg);

        fprintf('  %d steps, %.1fs wall, max_retraction=%.3e\n', stats.nsteps, stats.elapsed, stats.max_retraction);
        fprintf('  AUV0 chi(end) = [%s]\n', num2str(chi0', '%10.6f'));
        fprintf('  AUV0 s(end)   = [%s]\n', num2str(s0', '%10.4f'));
        fprintf('  AUV0 max|tau_cmd(end)| = %.6e\n', max(abs(tau_cmd0)));

        results.(field) = struct('eps', eps_v, 't', t_hist(end), 'chi0', chi0, 's0', s0, ...
            'tau_cmd0', tau_cmd0, 'stats', stats);
    end

    fprintf('\n=== COMPARISON (AUV0 chi_x at t=%.2f across eps) ===\n', t_final);
    chi_x_vals = zeros(numel(eps_list), 1);
    for ei = 1:numel(eps_list)
        field = sprintf('eps_%d', ei);
        chi_x_vals(ei) = results.(field).chi0(1);
        fprintf('  eps=%.1e  chi0_x=%.6f\n', eps_list(ei), chi_x_vals(ei));
    end

    spread = max(chi_x_vals) - min(chi_x_vals);
    ref_scale = max(abs(chi_x_vals));
    rel_spread = spread / max(1e-9, ref_scale);
    fprintf('\nabsolute spread across eps = %.6e, relative spread = %.4e\n', spread, rel_spread);
    if rel_spread < 1e-2
        fprintf('RESULT: closed-loop trajectory is NOT meaningfully sensitive to eps in this range (<1%% relative spread). Default eps=1e-6 is fine.\n');
    else
        fprintf('RESULT: closed-loop trajectory IS meaningfully sensitive to eps in this range (>=1%% relative spread) -- needs further investigation before trusting a single default.\n');
    end

    save('p1b_result.mat', 'results');
    fprintf('\n=== END P.1b (result saved to p1b_result.mat) ===\n');
end
