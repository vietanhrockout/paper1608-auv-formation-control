function diagnose_stepP2_micro_horizon_ab_test(t_final, h)
    % DIAGNOSE_STEPP2_MICRO_HORIZON_AB_TEST
    % Issue P closed-loop A/B test: runs the SAME production integrator
    % (projected_rk4_integrate.m) over a short horizon under both
    % inverse_lambda_mode branches ('paper_signed' = current default vs.
    % 'proof_consistent_unsigned' = Step P.1's algebraically-derived fix),
    % and compares AUV0 (leader) formation error chi trajectories.
    %
    % Per audit Rule 5 (no full-horizon sims during diagnostic sub-steps),
    % this uses a short horizon only (default 2s) before any conclusion is
    % drawn about whether Issue P is the (or a) root cause of Issue O.

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 2.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end

    cfg = nn_config();
    sat_cfg = saturation_config();

    modes = {'paper_signed', 'proof_consistent_unsigned'};
    results = struct();

    for m = 1:numel(modes)
        mode = modes{m};
        params = simulation_params();
        params.inverse_lambda_mode = mode;

        fprintf('=== Running mode=%s, t_final=%.2f, h=%.1e ===\n', mode, t_final, h);

        [eta_init, nu_init] = initial_conditions();
        omega_aw_mat = zeros(6, 3);
        Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
        Wc_mat = zeros(cfg.critic_n_nodes, 3);
        X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

        [t_full, X_full, stats] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg);

        fprintf('  done: %d steps, %.1fs wall, max_retraction=%.3e, total_retracted=%d\n', ...
            stats.nsteps, stats.elapsed, stats.max_retraction, stats.total_retracted);

        N = numel(t_full);
        chi0_x = zeros(N, 1);
        chi0_y = zeros(N, 1);
        chi0_z = zeros(N, 1);
        for k = 1:N
            Xk = X_full(k, :).';
            [eta_m, nu_m, ~, ~, ~] = unpack_states(Xk, cfg);
            eta0 = eta_m(:, 1);
            J0 = jacobian_J(eta0);
            eta0_dot = J0 * nu_m(:, 1);
            [chi0, ~] = formation_error(eta0, eta0_dot, t_full(k), 1);
            chi0_x(k) = chi0(1);
            chi0_y(k) = chi0(2);
            chi0_z(k) = chi0(3);
        end

        results.(mode).t = t_full;
        results.(mode).chi0_x = chi0_x;
        results.(mode).chi0_y = chi0_y;
        results.(mode).chi0_z = chi0_z;
        results.(mode).stats = stats;

        sample_idx = round(linspace(1, N, 6));
        fprintf('  AUV0 chi trajectory (t, chi_x, chi_y, chi_z):\n');
        for si = sample_idx
            fprintf('    t=%.4f  chi=[%.4f, %.4f, %.4f]\n', t_full(si), chi0_x(si), chi0_y(si), chi0_z(si));
        end
        fprintf('\n');
    end

    fprintf('=== COMPARISON ===\n');
    chi0_paper_start = abs(results.paper_signed.chi0_x(1));
    chi0_paper_end    = abs(results.paper_signed.chi0_x(end));
    chi0_fixed_start  = abs(results.proof_consistent_unsigned.chi0_x(1));
    chi0_fixed_end    = abs(results.proof_consistent_unsigned.chi0_x(end));

    fprintf('paper_signed:              |chi0_x| start=%.4f -> end=%.4f (%s)\n', ...
        chi0_paper_start, chi0_paper_end, tern(chi0_paper_end < chi0_paper_start, 'DECREASED', 'DID NOT DECREASE'));
    fprintf('proof_consistent_unsigned: |chi0_x| start=%.4f -> end=%.4f (%s)\n', ...
        chi0_fixed_start, chi0_fixed_end, tern(chi0_fixed_end < chi0_fixed_start, 'DECREASED', 'DID NOT DECREASE'));

    if chi0_fixed_end < chi0_fixed_start && chi0_fixed_end < chi0_paper_end
        fprintf('\nRESULT: proof_consistent_unsigned shows genuine leader chi convergence where paper_signed does not.\n');
        fprintf('Issue P hypothesis SUPPORTED by closed-loop micro-horizon evidence.\n');
    else
        fprintf('\nRESULT: proof_consistent_unsigned did NOT show the expected convergence improvement.\n');
        fprintf('Issue P hypothesis NOT supported by this closed-loop test -- do not adopt the fix based on P.1 algebra alone.\n');
    end

    save(sprintf('p2_result_t%.0f.mat', t_final), 'results');
end

function s = tern(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end
