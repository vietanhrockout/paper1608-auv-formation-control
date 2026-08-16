function diagnose_stepP4_h_convergence_under_fix(t_span, h_coarse, h_fine)
    % DIAGNOSE_STEPP4_H_CONVERGENCE_UNDER_FIX
    % The Step K.7 h=1e-4 vs h=1e-5 convergence check (quoted in earlier
    % handoff passes) was run under the OLD 'paper_signed' dynamics, where
    % chi is essentially frozen -- a near-static vector field is trivially
    % easy for any step size to integrate accurately, so that check says
    % nothing about accuracy now that Issue P's fix ('proof_consistent_unsigned',
    % now the production default) makes chi move quickly and the closed-loop
    % genuinely converge. This script re-runs the same style of check under
    % the NEW default dynamics, from t=0 (the fastest, most dynamic part of
    % the trajectory), and SAVES a proper result file (the old check's
    % scripts/logs/results were found to not exist in the repo during the
    % independent audit -- fixing that gap here).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_span)
        t_span = 0.3;
    end
    if nargin < 2 || isempty(h_coarse)
        h_coarse = 1e-4;
    end
    if nargin < 3 || isempty(h_fine)
        h_fine = 1e-5;
    end

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = simulation_params(); % picks up the new default inverse_lambda_mode

    fprintf('params.inverse_lambda_mode = %s\n', params.inverse_lambda_mode);

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    fprintf('=== Coarse run: h=%.1e, t_span=%.2f ===\n', h_coarse, t_span);
    [t_c, X_c, stats_c] = projected_rk4_integrate(t_span, h_coarse, X0, params, sat_cfg, cfg);
    fprintf('  %d steps, %.1fs wall\n', stats_c.nsteps, stats_c.elapsed);

    fprintf('=== Fine run: h=%.1e, t_span=%.2f ===\n', h_fine, t_span);
    [t_f, X_f, stats_f] = projected_rk4_integrate(t_span, h_fine, X0, params, sat_cfg, cfg);
    fprintf('  %d steps, %.1fs wall\n', stats_f.nsteps, stats_f.elapsed);

    Xc_end = X_c(end, :);
    Xf_end = X_f(end, :);

    [eta_c, nu_c, ~, ~, Wc_c] = unpack_states(Xc_end.', cfg);
    [eta_f, nu_f, ~, ~, Wc_f] = unpack_states(Xf_end.', cfg);

    d_eta = abs(eta_c - eta_f);
    d_nu = abs(nu_c - nu_f);
    d_Wc = abs(Wc_c - Wc_f);

    fprintf('\n=== Endpoint comparison at t=%.2f ===\n', t_span);
    fprintf('max|d_eta| = %.6e\n', max(d_eta(:)));
    fprintf('max|d_nu|  = %.6e\n', max(d_nu(:)));
    fprintf('max|d_Wc|  = %.6e\n', max(d_Wc(:)));
    fprintf('AUV0 eta_coarse = [%s]\n', num2str(eta_c(:,1)', '%10.6f'));
    fprintf('AUV0 eta_fine   = [%s]\n', num2str(eta_f(:,1)', '%10.6f'));
    fprintf('AUV0 nu_coarse  = [%s]\n', num2str(nu_c(:,1)', '%10.6f'));
    fprintf('AUV0 nu_fine    = [%s]\n', num2str(nu_f(:,1)', '%10.6f'));

    rel_eta = max(d_eta(:)) / max(1e-9, max(abs(eta_f(:))));
    rel_nu  = max(d_nu(:))  / max(1e-9, max(abs(nu_f(:))));
    fprintf('\nrelative max|d_eta| = %.4e, relative max|d_nu| = %.4e\n', rel_eta, rel_nu);

    result = struct();
    result.t_span = t_span; result.h_coarse = h_coarse; result.h_fine = h_fine;
    result.max_d_eta = max(d_eta(:)); result.max_d_nu = max(d_nu(:)); result.max_d_Wc = max(d_Wc(:));
    result.rel_eta = rel_eta; result.rel_nu = rel_nu;
    result.stats_coarse = stats_c; result.stats_fine = stats_f;
    save('p4_result.mat', 'result');

    fprintf('\n=== END P.4 (result saved to p4_result.mat) ===\n');
end
