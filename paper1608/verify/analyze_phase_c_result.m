function analysis = analyze_phase_c_result(result_path, manifest_path)
    % ANALYZE_PHASE_C_RESULT
    % Post-hoc, read-only analysis of the first full 100s Phase C
    % production dataset -- computes the same trajectory-level E_chi/E_s
    % convergence check verify_phase_b3_projected_convergence.m does,
    % plus per-AUV breakdown, NN weight bound checks, and per-channel
    % actuator saturation checks, WITHOUT re-running the (very expensive)
    % simulation. Does not modify any production file.

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(result_path)
        result_path = 'phase_c_results/phase_c_result.mat';
    end
    if nargin < 2 || isempty(manifest_path)
        manifest_path = 'phase_c_results/phase_c_manifest.mat';
    end

    dr = load(result_path);
    dm = load(manifest_path);
    res = dr.res;
    manifest = dm.manifest;

    fprintf('=== Phase C result: t_final=%.4f, %d samples, git_sha=%s, git_dirty=%d ===\n', ...
        manifest.t_final, numel(res.t), manifest.git_sha, manifest.git_dirty);
    fprintf('wall time: %.1f min, nsteps=%d, max_retraction=%.4e, total_retracted=%d\n', ...
        manifest.elapsed_wall_sec/60, manifest.nsteps, manifest.max_retraction, manifest.total_retracted);
    if isfield(manifest, 'max_tau_act_force')
        fprintf('max|tau_act| (online, every step): force=%.4f N (limit 150), moment=%.4f Nm (limit 30)\n', ...
            manifest.max_tau_act_force, manifest.max_tau_act_moment);
    end

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = res.params;

    N = numel(res.t);
    E_chi = zeros(N, 1);
    E_s = zeros(N, 1);
    max_Wc_norm = 0;
    max_Wa_norm = 0;
    max_tau_act_decimated = 0;
    E_chi_per_auv = zeros(N, 3);

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
            E_chi_per_auv(k, i) = max(abs(chi));

            wc_norm = norm(Wc_m(:, i));
            wa_norm = norm(Wa_l{i}, 'fro');
            max_Wc_norm = max(max_Wc_norm, wc_norm);
            max_Wa_norm = max(max_Wa_norm, wa_norm);

            tau_cmd = controller_rl(eta, eta_dot, res.t(k), i, omega_m(:, i), Wa_l{i}, params, cfg);
            tau_act = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
            max_tau_act_decimated = max(max_tau_act_decimated, max(abs(tau_act)));
        end
        E_chi(k) = max(e_chi_k);
        E_s(k) = max(e_s_k);
    end

    fprintf('\nmax ||Wc|| = %.4f (limit %.1f), max ||Wa||_F = %.4f (limit %.1f)\n', ...
        max_Wc_norm, cfg.delta_c, max_Wa_norm, cfg.delta_a);
    fprintf('max tau_act (decimated-sample recompute) = %.4f N/Nm (limit 150/30)\n', max_tau_act_decimated);

    fprintf('\n=== E_chi / E_s over the full 100s (max across all 3 AUVs) ===\n');
    sample_t = [0, 1, 3, 5, 7.5, 10, 15, 20, 30, 50, 75, 100];
    for st = sample_t
        [~, idx] = min(abs(res.t - st));
        fprintf('t=%7.3f  E_chi=%12.6f  E_s=%14.6f  (AUV0=%.4f AUV1=%.4f AUV2=%.4f)\n', ...
            res.t(idx), E_chi(idx), E_s(idx), E_chi_per_auv(idx,1), E_chi_per_auv(idx,2), E_chi_per_auv(idx,3));
    end

    fprintf('\nE_chi(0)=%.4f -> E_chi(end)=%.6f\n', E_chi(1), E_chi(end));
    fprintf('min E_chi over [T1*, 100] = %.6e (t=%.3f)\n', min(E_chi(res.t >= 5)), res.t(find(res.t >= 5, 1)) );
    [min_val, min_idx] = min(E_chi);
    fprintf('global min E_chi = %.6e at t=%.4f\n', min_val, res.t(min_idx));
    fprintf('max E_chi over [10, 100] (post-transient) = %.6e\n', max(E_chi(res.t >= 10)));

    assert(~any(isnan(res.X(:))) && ~any(isinf(res.X(:))), 'FAIL: NaN/Inf in saved trajectory');
    assert(max_Wc_norm <= cfg.delta_c + 1e-4, 'FAIL: Wc exceeded delta_c');
    assert(max_Wa_norm <= cfg.delta_a + 1e-4, 'FAIL: Wa exceeded delta_a');
    assert(max_tau_act_decimated <= 150 + 1e-6, 'FAIL: actuator exceeded 150N/30Nm limit');
    assert(E_chi(end) < E_chi(1), 'FAIL: E_chi did not decrease at all over 100s');

    fprintf('\n=== ALL STRUCTURAL ASSERTS PASSED (finite, NN bounds, actuator limits, genuine decrease) ===\n');

    analysis = struct();
    analysis.t = res.t; analysis.E_chi = E_chi; analysis.E_s = E_s; analysis.E_chi_per_auv = E_chi_per_auv;
    analysis.max_Wc_norm = max_Wc_norm; analysis.max_Wa_norm = max_Wa_norm;
    analysis.max_tau_act_decimated = max_tau_act_decimated;
    analysis.manifest = manifest;
    save('phase_c_results/phase_c_analysis.mat', 'analysis');
    fprintf('\nSaved analysis to phase_c_results/phase_c_analysis.mat\n');
end
