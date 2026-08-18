function analysis = analyze_phase_c_result(result_path, manifest_path)
    % ANALYZE_PHASE_C_RESULT
    % Post-hoc, read-only analysis of the first full 100s Phase C
    % production dataset -- computes the same trajectory-level E_chi/E_s
    % convergence check verify_phase_b3_projected_convergence.m does,
    % plus per-AUV breakdown, NN weight bound checks, and per-channel
    % actuator saturation checks, WITHOUT re-running the (very expensive)
    % simulation. Does not modify any production file.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(project_root));
    paths = project_paths();

    if nargin < 1 || isempty(result_path)
        result_path = fullfile(paths.phase_c_work, 'phase_c_result.mat');
    end
    if nargin < 2 || isempty(manifest_path)
        manifest_path = fullfile(paths.phase_c_work, 'phase_c_manifest.mat');
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
    max_tau_act_force_decimated = 0;
    max_tau_act_moment_decimated = 0;
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
            max_tau_act_force_decimated = max(max_tau_act_force_decimated, max(abs(tau_act(1:3))));
            max_tau_act_moment_decimated = max(max_tau_act_moment_decimated, max(abs(tau_act(4:6))));
        end
        E_chi(k) = max(e_chi_k);
        E_s(k) = max(e_s_k);
    end

    fprintf('\nmax ||Wc|| = %.4f (limit %.1f), max ||Wa||_F = %.4f (limit %.1f)\n', ...
        max_Wc_norm, cfg.delta_c, max_Wa_norm, cfg.delta_a);
    fprintf('max tau_act (decimated-sample recompute): force=%.4f N (limit 150), moment=%.4f Nm (limit 30)\n', ...
        max_tau_act_force_decimated, max_tau_act_moment_decimated);

    fprintf('\n=== E_chi / E_s over the full 100s (max across all 3 AUVs) ===\n');
    sample_t = [0, 1, 3, 5, 7.5, 10, 15, 20, 30, 50, 75, 100];
    for st = sample_t
        [~, idx] = min(abs(res.t - st));
        fprintf('t=%7.3f  E_chi=%12.6f  E_s=%14.6f  (AUV0=%.4f AUV1=%.4f AUV2=%.4f)\n', ...
            res.t(idx), E_chi(idx), E_s(idx), E_chi_per_auv(idx,1), E_chi_per_auv(idx,2), E_chi_per_auv(idx,3));
    end

    mask10 = res.t >= 10;
    [min_val_10, min_idx_10_rel] = min(E_chi(mask10));
    idx10_all = find(mask10);
    min_idx_10 = idx10_all(min_idx_10_rel);
    max_chi_10_100 = max(E_chi(mask10));

    fprintf('\nE_chi(0)=%.4f -> E_chi(end)=%.6f\n', E_chi(1), E_chi(end));
    fprintf('min E_chi over [T1*+T2*=10, 100] = %.6e at t=%.4f (index of the actual minimum, not first t>=10)\n', ...
        min_val_10, res.t(min_idx_10));
    [min_val, min_idx] = min(E_chi);
    fprintf('global min E_chi = %.6e at t=%.4f\n', min_val, res.t(min_idx));
    fprintf('max E_chi over [10, 100] (post-transient) = %.6e\n', max_chi_10_100);

    fprintf('\nNOTE: T1*=5s is the paper''s configured predefined-time reaching deadline, but the\n');
    fprintf('sliding-surface/tracking-error data does NOT reach a small neighborhood by t=5s\n');
    fprintf('(see t=5 row above). The combined horizon T1*+T2*=10s is the earliest declared\n');
    fprintf('deadline consistent with the observed data; entry into a small neighborhood is\n');
    fprintf('observed empirically around t~7.1-7.5s. See diagnose_stepR8_crossing_times.m for\n');
    fprintf('exact first-entry/sustained-entry crossing times -- do not infer them from this\n');
    fprintf('sparse table alone.\n');

    % --- Structural validity (finiteness, NN bounds, actuator hard limits) ---
    assert(~any(isnan(res.X(:))) && ~any(isinf(res.X(:))), 'FAIL: NaN/Inf in saved trajectory');
    assert(max_Wc_norm <= cfg.delta_c + 1e-4, 'FAIL: Wc exceeded delta_c');
    assert(max_Wa_norm <= cfg.delta_a + 1e-4, 'FAIL: Wa exceeded delta_a');
    assert(max_tau_act_force_decimated <= 150 + 1e-6, 'FAIL: actuator force exceeded 150N limit (decimated recompute)');
    assert(max_tau_act_moment_decimated <= 30 + 1e-6, 'FAIL: actuator moment exceeded 30Nm limit (decimated recompute)');
    if isfield(manifest, 'max_tau_act_force')
        assert(manifest.max_tau_act_force <= 150 + 1e-6, 'FAIL: online actuator force exceeded 150N limit');
        assert(manifest.max_tau_act_moment <= 30 + 1e-6, 'FAIL: online actuator moment exceeded 30Nm limit');
    end
    fprintf('\n=== STRUCTURAL ASSERTS PASSED (finite, NN bounds, actuator limits) ===\n');

    % --- Scientific convergence (separate verdict group, declared tolerances) ---
    % Tolerances chosen with margin above the actual observed values
    % (E_chi(t=10)=2.6e-3, max[10,100]=1.6e-2, E_chi(end)=1.5e-2) so the
    % assertion is a real regression check, not a rubber stamp.
    chi_tol_10s = 0.02;
    chi_tol_post_transient = 0.02;
    chi_tol_final = 0.02;

    [~, idx10] = min(abs(res.t - 10));
    assert(E_chi(idx10) <= chi_tol_10s, ...
        sprintf('FAIL: E_chi=%.4e at t=%.3f exceeds tracking-neighborhood tolerance %.4g by the combined T1*+T2*=10s horizon', ...
        E_chi(idx10), res.t(idx10), chi_tol_10s));
    assert(max_chi_10_100 <= chi_tol_post_transient, ...
        sprintf('FAIL: max E_chi over [10,100]=%.4e exceeds post-transient tolerance %.4g', ...
        max_chi_10_100, chi_tol_post_transient));
    assert(E_chi(end) <= chi_tol_final, ...
        sprintf('FAIL: final E_chi=%.4e exceeds tolerance %.4g', E_chi(end), chi_tol_final));
    assert(E_chi(end) < E_chi(1), 'FAIL: E_chi did not decrease at all over 100s');

    fprintf('=== CONVERGENCE ASSERTS PASSED (neighborhood entry by 10s, bounded post-transient, bounded final; tol=%.4g) ===\n', chi_tol_final);
    fprintf('NOTE: these asserts do NOT establish the unqualified T1*=5s exact reaching-deadline claim -- see REVIEW_GPT_2026-08-17_R8.md.\n');

    analysis = struct();
    analysis.t = res.t; analysis.E_chi = E_chi; analysis.E_s = E_s; analysis.E_chi_per_auv = E_chi_per_auv;
    analysis.max_Wc_norm = max_Wc_norm; analysis.max_Wa_norm = max_Wa_norm;
    analysis.max_tau_act_force_decimated = max_tau_act_force_decimated;
    analysis.max_tau_act_moment_decimated = max_tau_act_moment_decimated;
    analysis.manifest = manifest;
    analysis_path = fullfile(paths.phase_c_work, 'phase_c_analysis.mat');
    save(analysis_path, 'analysis');
    fprintf('\nSaved analysis to %s\n', analysis_path);
end
