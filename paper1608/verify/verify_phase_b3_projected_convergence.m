function result = verify_phase_b3_projected_convergence(t_final, h, require_neighborhood)
    % VERIFY_PHASE_B3_PROJECTED_CONVERGENCE
    % Proper assert-based Phase B checker for exp4_rl_pts_mc_projected.m
    % running under the NEW production default (Issue P fix,
    % params.inverse_lambda_mode = 'proof_consistent_unsigned').
    %
    % Supersedes run_phase_b2.m's ad-hoc printer, which never actually
    % asserted on convergence -- an independent audit flagged that gap
    % (Phase B.2 "succeeded" numerically while silently failing on the
    % actual control objective). This script asserts on:
    %   1. No NaN/Inf anywhere in the state history.
    %   2. ||Wc_i|| <= delta_c (+tol) and ||Wa_i||_F <= delta_a (+tol) for
    %      every AUV at every sample (structural NN-weight-projection bound).
    %   3. |tau_act| never exceeds tau_max (actuator saturation respected).
    %   4. GENUINE CONVERGENCE: max|chi_i| across all 3 AUVs at t_final is
    %      below a "small neighborhood of the origin" threshold, AND is
    %      meaningfully smaller than at t=0 (not just numerically finite).
    %      This is the assertion that was MISSING from run_phase_b2.m and
    %      is exactly what would have caught Issue O/P earlier. A second
    %      independent audit (GPT, via the public GitHub repo) caught that
    %      THIS specific check was only ever fprintf'd, never actually
    %      asserted -- a bad run could still be mislabeled "all structural
    %      asserts PASSED". Fixed: now a real assert by default
    %      (require_neighborhood=true). Pass false only when deliberately
    %      testing a horizon shorter than the paper's own claimed
    %      convergence time (e.g. t_final < T1*=5s), where partial
    %      convergence is the expected, non-failing outcome.

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 15.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end
    if nargin < 3 || isempty(require_neighborhood)
        require_neighborhood = true;
    end

    res = exp4_rl_pts_mc_projected(t_final, h);
    save(sprintf('phase_b3_result_t%.0f.mat', t_final), 'res');

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = res.params;

    fprintf('params.inverse_lambda_mode = %s\n', params.inverse_lambda_mode);

    N = length(res.t);
    E_chi = zeros(N, 1);
    E_s = zeros(N, 1);
    max_tau_act = 0;
    max_Wc_norm = 0;
    max_Wa_norm = 0;

    for k = 1:N
        Xk = res.X(k, :).';
        [eta_m, nu_m, omega_m, Wa_l, Wc_m] = unpack_states(Xk, cfg);
        e_chi_k = zeros(3, 1);
        e_s_k = zeros(3, 1);
        for i = 1:3
            eta = eta_m(:, i); nu = nu_m(:, i);
            J = jacobian_J(eta); eta_dot = J * nu;
            [chi, vel_err] = formation_error(eta, eta_dot, res.t(k), i);
            s = sliding_surface(chi, vel_err, params);
            e_chi_k(i) = max(abs(chi));
            e_s_k(i) = max(abs(s));

            wc_norm = norm(Wc_m(:, i));
            wa_norm = norm(Wa_l{i}, 'fro');
            max_Wc_norm = max(max_Wc_norm, wc_norm);
            max_Wa_norm = max(max_Wa_norm, wa_norm);
            assert(wc_norm <= cfg.delta_c + 1e-4, ...
                'AUV%d ||Wc||=%.6f exceeds delta_c=%.4f at t=%.4f', i-1, wc_norm, cfg.delta_c, res.t(k));
            assert(wa_norm <= cfg.delta_a + 1e-4, ...
                'AUV%d ||Wa||_F=%.6f exceeds delta_a=%.4f at t=%.4f', i-1, wa_norm, cfg.delta_a, res.t(k));

            tau_cmd = controller_rl(eta, eta_dot, res.t(k), i, omega_m(:, i), Wa_l{i}, params, cfg);
            [tau_act, ~] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
            max_tau_act = max(max_tau_act, max(abs(tau_act)));
            assert(all(abs(tau_act) <= sat_cfg.tau_max + 1e-9), ...
                'AUV%d actuator exceeds tau_max at t=%.4f', i-1, res.t(k));
        end
        E_chi(k) = max(e_chi_k);
        E_s(k) = max(e_s_k);
    end

    assert(~any(isnan(res.X(:))) && ~any(isinf(res.X(:))), 'NaN/Inf found in state history');

    fprintf('\n=== PHASE B.3 SUMMARY (Issue P fix, t_final=%.2f, h=%.1e) ===\n', t_final, h);
    fprintf('nsteps=%d, wall=%.1fs, max_retraction=%.4e, total_retracted=%d\n', ...
        res.stats.nsteps, res.stats.elapsed, res.stats.max_retraction, res.stats.total_retracted);
    fprintf('max tau_act = %.4f N/Nm (limit 150/30)\n', max_tau_act);
    fprintf('max ||Wc|| = %.4f (limit %.1f), max ||Wa||_F = %.4f (limit %.1f)\n', ...
        max_Wc_norm, cfg.delta_c, max_Wa_norm, cfg.delta_a);
    sample_t = unique([0, t_final*0.1, t_final*0.25, t_final*(5/t_final), t_final*0.5, t_final*0.75, t_final]);
    for st = sample_t
        [~, idx] = min(abs(res.t - st));
        fprintf('t=%7.3f  E_chi=%10.4f  E_s=%12.4f\n', res.t(idx), E_chi(idx), E_s(idx));
    end

    E_chi_0 = E_chi(1);
    E_chi_end = E_chi(end);
    fprintf('\nE_chi(0)=%.4f -> E_chi(end)=%.4f\n', E_chi_0, E_chi_end);

    CONVERGENCE_NEIGHBORHOOD = 2.0; % "small neighborhood of origin" threshold, project-chosen
    assert(E_chi_end < E_chi_0, ...
        'FAIL: E_chi did not decrease at all (E_chi(0)=%.4f, E_chi(end)=%.4f) -- non-convergence', E_chi_0, E_chi_end);
    if require_neighborhood
        assert(E_chi_end < CONVERGENCE_NEIGHBORHOOD, ...
            'FAIL: E_chi(end)=%.4f has NOT reached the %.1f-unit convergence neighborhood (E_chi(0)=%.4f) -- run does not qualify as converged', ...
            E_chi_end, CONVERGENCE_NEIGHBORHOOD, E_chi_0);
        fprintf('PASS: E_chi(end)=%.4f is within the %.1f-unit convergence neighborhood.\n', E_chi_end, CONVERGENCE_NEIGHBORHOOD);
    elseif E_chi_end < CONVERGENCE_NEIGHBORHOOD
        fprintf('PASS: E_chi(end)=%.4f is within the %.1f-unit convergence neighborhood.\n', E_chi_end, CONVERGENCE_NEIGHBORHOOD);
    else
        fprintf('PARTIAL (require_neighborhood=false, not a failure): E_chi decreased (%.4f -> %.4f) but has NOT yet reached the %.1f-unit neighborhood.\n', ...
            E_chi_0, E_chi_end, CONVERGENCE_NEIGHBORHOOD);
    end

    result = struct();
    result.t = res.t; result.E_chi = E_chi; result.E_s = E_s;
    result.max_tau_act = max_tau_act; result.max_Wc_norm = max_Wc_norm; result.max_Wa_norm = max_Wa_norm;
    result.stats = res.stats;
    save(sprintf('phase_b3_checker_result_t%.0f.mat', t_final), 'result');

    fprintf('=== END PHASE B.3 (all structural asserts PASSED; see convergence verdict above) ===\n');
end
