function diagnose_stepS2_cost_to_go_validity()
    % DIAGNOSE_STEPS2_COST_TO_GO_VALIDITY
    % Read-only value-function validation for Fig. 4, requested by
    % REVIEW_GPT_2026-08-25_R17.md items 1-3. Answers a question the existing
    % critic oracles never ask: does Chat actually approximate the Eq. (15)
    % return of the trajectory that was executed?
    %
    % verify_step34/36/37 only check that the critic output is finite, that
    % the Bellman error has the right shape, and that the update equals its
    % own algebraic expression. None of them compares Chat to anything.
    %
    % METHOD
    %   Recompute, at every stored sample of the committed Phase-C run:
    %     r(t_k)   = chi'*B*chi + tau_act'*R*tau_act        (Eq. 16, saturated
    %                input per the supervisor determination)
    %     Chat(t_k)= Wc(t_k)' * theta_c(chi(t_k))           (Eq. 14)
    %   then backward-accumulate the discounted return (Eq. 15):
    %     C_trunc(t_k) = sum_{l>=k} exp(-(t_l-t_k)/lambda) * r(t_l) * dt
    %
    %   Because r >= 0, truncating at T=100 s can only UNDER-estimate the true
    %   return, so C_trunc is a strict LOWER BOUND on Eq. (15). A second
    %   variant adds an explicit constant-r tail assumption:
    %     C_tail(t_k) = C_trunc(t_k) + lambda * r(T) * exp(-(T-t_k)/lambda)
    %   Both are reported; neither is presented as the exact return.
    %
    % HONEST LIMITS OF THIS ESTIMATE -- stated up front:
    %   * The committed artifact stores 1003 decimated samples over 100 s
    %     (dt ~ 0.0998 s). The reward during the sub-second reaching transient
    %     is therefore badly under-resolved, and C_return near t=0 is
    %     correspondingly crude. It is still far more than accurate enough to
    %     settle a SIGN question.
    %   * tau_act is recomputed from the stored state, not replayed from the
    %     integrator's own per-step values, so it is the decimated-sample
    %     reconstruction rather than the exact signal the critic saw.
    %   * No claim is made that Chat "should" equal C_return under the paper's
    %     theory: the paper proves weight boundedness, not value convergence.
    %     What this script establishes is narrower and harder to dispute --
    %     the SIGN is wrong, and by how much.

    paths = project_paths();
    cfg = nn_config();

    d = load(fullfile(paths.phase_c, 'phase_c_result_t100.mat'));
    res = d.res;
    params = res.params;
    sat_cfg = saturation_config();

    lambda = params.lambda;
    B = eye(6);
    R = 1e-4 * eye(6);

    N = numel(res.t);
    t = res.t(:);
    r = zeros(N, 3);
    Chat = zeros(N, 3);

    fprintf('=== Step S2: is Chat a valid Eq.(15) cost-to-go? ===\n\n');
    fprintf('dataset: %s\n', fullfile(paths.phase_c, 'phase_c_result_t100.mat'));
    fprintf('samples=%d  horizon=[%.3f, %.3f]s  mean dt=%.6fs  lambda=%.4f\n', ...
        N, t(1), t(end), mean(diff(t)), lambda);
    fprintf('reward mode=%s  (B=I6, R=1e-4*I6, both ASSUMED -- Issue N)\n\n', ...
        params.critic_reward_tau_mode);

    for k = 1:N
        [eta_m, nu_m, omega_m, Wa_l, Wc_m] = unpack_states(res.X(k, :).', cfg);
        for i = 1:3
            eta_i = eta_m(:, i);
            eta_dot_i = jacobian_J(eta_i) * nu_m(:, i);
            chi_i = formation_error(eta_i, eta_dot_i, t(k), i);

            tau_cmd = controller_rl(eta_i, eta_dot_i, t(k), i, omega_m(:, i), Wa_l{i}, params, cfg);
            tau_act = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);

            r(k, i) = chi_i.' * B * chi_i + tau_act.' * R * tau_act;
            Chat(k, i) = critic_output(chi_i, Wc_m(:, i), cfg);
        end
    end

    assert(all(r(:) >= 0), 'STEP S2: r(t) went negative -- the PSD reward assumption is broken');

    % Backward discounted accumulation, trapezoid on the stored grid.
    C_trunc = zeros(N, 3);
    for i = 1:3
        acc = 0;
        C_trunc(N, i) = 0;
        for k = N-1:-1:1
            dt = t(k+1) - t(k);
            decay = exp(-dt / lambda);
            % contribution of [t_k, t_k+1] plus the discounted remainder
            acc = 0.5 * dt * (r(k, i) + decay * r(k+1, i)) + decay * acc;
            C_trunc(k, i) = acc;
        end
    end
    C_tail = C_trunc + lambda * (ones(N,1) * r(N, :)) .* exp(-(t(end) - t) / lambda);

    fprintf('--- Chat vs the backward discounted return, at selected times ---\n');
    fprintf('%8s %26s %26s %26s\n', 't (s)', 'AUV0  Chat / C_trunc', 'AUV1  Chat / C_trunc', 'AUV2  Chat / C_trunc');
    for tt = [0 1 5 10 25 50 75 100]
        [~, k] = min(abs(t - tt));
        fprintf('%8.3f', t(k));
        for i = 1:3
            fprintf('  %11.4f /%11.4f', Chat(k, i), C_trunc(k, i));
        end
        fprintf('\n');
    end

    fprintf('\n--- Verdict per AUV ---\n');
    verdict_ok = true;
    for i = 1:3
        n_neg = sum(Chat(:, i) < 0);
        fprintf('AUV%d: Chat range [%.4f, %.4f]; %d/%d samples NEGATIVE (%.1f%%)\n', ...
            i-1, min(Chat(:, i)), max(Chat(:, i)), n_neg, N, 100*n_neg/N);
        fprintf('      C_trunc(0)=%.4f (strict LOWER bound on the true return)\n', C_trunc(1, i));
        fprintf('      C_tail(0) =%.4f (with constant-r tail past t=100s)\n', C_tail(1, i));
        fprintf('      Chat(0)=%.4f  =>  signed error vs lower bound = %.4f\n', ...
            Chat(1, i), Chat(1, i) - C_trunc(1, i));
        if min(Chat(:, i)) < 0
            verdict_ok = false;
        end
    end

    % Late-horizon trend: is Chat converged, or still moving?
    fprintf('\n--- Late-horizon trend over [50,100]s (is it a plateau?) ---\n');
    late = t >= 50;
    for i = 1:3
        pf = polyfit(t(late), Chat(late, i), 1);
        k50 = find(late, 1);
        fprintf('AUV%d: Chat 50s=%.4f -> 100s=%.4f, slope=%+.6f/s (%+.2f%% over 50s)\n', ...
            i-1, Chat(k50, i), Chat(end, i), pf(1), ...
            100*(Chat(end,i)-Chat(k50,i))/abs(Chat(k50,i)));
    end

    fprintf('\n=== CONCLUSION ===\n');
    if verdict_ok
        fprintf('Chat is non-negative throughout -- the sign defect is NOT present in this dataset.\n');
    else
        fprintf(['Chat is NEGATIVE over most of the run while the true Eq.(15) return is\n' ...
                 'bounded BELOW by a large positive number. Chat therefore does not\n' ...
                 'approximate the cost-to-go of the executed trajectory: it has the wrong\n' ...
                 'SIGN, not merely the wrong scale. Fig. 4 must stay a provisional\n' ...
                 'diagnostic. Root cause and the Phi''*theta mechanism: R17.\n' ...
                 'This script does NOT propose a fix -- a positivity-preserving critic\n' ...
                 'would be an experimental deviation from Eqs.(14)/(20) and would need\n' ...
                 'fresh closed-loop validation, because Chat feeds actor_update.\n']);
    end

    if ~exist(paths.phase_c_work, 'dir')
        mkdir(paths.phase_c_work);
    end
    out = fullfile(paths.phase_c_work, 'stepS2_cost_to_go_validity.mat');
    save(out, 't', 'r', 'Chat', 'C_trunc', 'C_tail', 'lambda');
    fprintf('\nSaved series to %s\n', out);
end
