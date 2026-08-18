function verify_step52_performance_criteria()
    % VERIFY_STEP52_PERFORMANCE_CRITERIA
    % Fast scientific regression gate for the accepted 100 s Phase-C run.
    %
    % HISTORY
    % -------------------------------------------------------------------
    % Originally a FALSE ORACLE (REVIEW_GPT_2026-08-18_R12.md [P1]): its
    % header advertised four criteria but the body ran
    % `exp4_rl_pts_mc(0.5, ...)` on the legacy stalling ode45 path and
    % checked ONLY actuator bounds at a single final sample. Criteria 1-3
    % were evaluated by no line of code, and its criterion 3 asserted the
    % literal T1*=5 s deadline that the accepted Phase-C evidence shows is
    % MISSED.
    %
    % The first rewrite then read the DERIVED cache
    % (phase_c_analysis_t100.mat) and trusted its E_chi. R13 [P1] correctly
    % objected: since this oracle is now the fast gate standing in for a
    % ~3.3 hour simulation, trusting a cached summary means a stale or
    % mismatched analysis/manifest pair could pass while saying nothing
    % about the committed raw trajectory.
    %
    % It therefore now RECOMPUTES E_chi from the raw committed result using
    % the production formation-error definition, checks pairing invariants
    % between result/manifest/analysis, and asserts the accepted criteria
    % on the recomputation. The cached analysis is compared against the
    % recomputation and a stale cache is a FAILURE, not a silent pass.
    % This is post-processing only -- it does NOT rerun Phase C.
    %
    % Criteria asserted (the ones the project actually accepts; see
    % docs/HANDOFF.md's Phase C section):
    %   1. Tracking neighborhood entered by the COMBINED horizon
    %      T1*+T2* = 10 s -- NOT by T1* = 5 s.
    %   2. Full-tail boundedness of E_chi over [10, 100] s.
    %   3. Bounded final E_chi at t = 100 s.
    %   4. Actuator force and moment limits, checked SEPARATELY
    %      (150 N / 30 N*m) against the online every-step manifest maxima.

    % Standalone path setup (R13 [P2]): this function must work from a
    % clean MATLAB session, not only when the master runner has already
    % called genpath. It reaches config/model/reference/math/control/nn
    % below, so add them explicitly rather than relying on caller state.
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(project_root);
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    paths = project_paths();
    result_path   = fullfile(paths.phase_c, 'phase_c_result_t100.mat');
    manifest_path = fullfile(paths.phase_c, 'phase_c_manifest_t100.mat');
    analysis_path = fullfile(paths.phase_c, 'phase_c_analysis_t100.mat');

    for p = {result_path, manifest_path, analysis_path}
        if exist(p{1}, 'file') ~= 2
            error('STEP 52: FAIL - missing committed artifact %s', p{1});
        end
    end

    dr = load(result_path);
    dm = load(manifest_path);
    da = load(analysis_path);
    res = dr.res;
    manifest = dm.manifest;
    analysis = da.analysis;

    % --- Pairing invariants: result <-> manifest <-> analysis ------------
    assert(abs(manifest.t_final - res.t(end)) < 1e-6, ...
        'STEP 52: FAIL - manifest t_final=%.6f does not match raw result end t=%.6f', ...
        manifest.t_final, res.t(end));
    assert(abs(res.t(end) - 100) < 1e-6, ...
        'STEP 52: FAIL - raw result horizon is %.6f s, expected 100 s', res.t(end));
    assert(size(res.X, 1) == numel(res.t), ...
        'STEP 52: FAIL - res.X rows (%d) != numel(res.t) (%d)', size(res.X, 1), numel(res.t));
    % Manifest <-> result pairing (R14 non-blocking hardening suggestion,
    % adopted: both fields were confirmed present before asserting on them).
    assert(manifest.stored_sample_count == numel(res.t), ...
        'STEP 52: FAIL - manifest stored_sample_count=%d but raw result has %d samples', ...
        manifest.stored_sample_count, numel(res.t));
    assert(isfield(res, 'stats') && isfield(res.stats, 'nsteps'), ...
        'STEP 52: FAIL - raw result lacks res.stats.nsteps');
    assert(manifest.nsteps == res.stats.nsteps, ...
        'STEP 52: FAIL - manifest nsteps=%d but res.stats.nsteps=%d (mismatched pair)', ...
        manifest.nsteps, res.stats.nsteps);

    assert(numel(analysis.t) == numel(res.t), ...
        'STEP 52: FAIL - cached analysis has %d samples, raw result has %d (stale cache)', ...
        numel(analysis.t), numel(res.t));
    assert(max(abs(analysis.t(:) - res.t(:))) < 1e-9, ...
        'STEP 52: FAIL - cached analysis time grid differs from the raw result (stale cache)');
    if isfield(analysis, 'manifest') && isfield(analysis.manifest, 'git_sha')
        assert(strcmp(analysis.manifest.git_sha, manifest.git_sha), ...
            'STEP 52: FAIL - analysis was produced from run %s but manifest is %s (mismatched pair)', ...
            analysis.manifest.git_sha, manifest.git_sha);
    end

    % --- Recompute E_chi from the RAW trajectory -------------------------
    cfg = nn_config();
    params = res.params;
    N = numel(res.t);
    E_chi = zeros(N, 1);
    for k = 1:N
        [eta_m, nu_m, ~, ~, ~] = unpack_states(res.X(k, :).', cfg);
        e_k = 0;
        for i = 1:3
            eta_i = eta_m(:, i);
            eta_dot_i = jacobian_J(eta_i) * nu_m(:, i);
            chi_i = formation_error(eta_i, eta_dot_i, res.t(k), i);
            e_k = max(e_k, max(abs(chi_i)));
        end
        E_chi(k) = e_k;
    end

    assert(all(isfinite(E_chi)), 'STEP 52: FAIL - non-finite E_chi recomputed from raw result');

    % Cache-staleness gate: the committed analysis must agree with what the
    % raw trajectory actually yields.
    cache_diff = max(abs(E_chi - analysis.E_chi(:)));
    assert(cache_diff < 1e-9, ...
        ['STEP 52: FAIL - cached analysis E_chi disagrees with recomputation from the raw ' ...
         'result (max diff %.3e). The committed phase_c_analysis_t100.mat is stale.'], cache_diff);

    % --- Declared tolerances --------------------------------------------
    % Real margin above the observed 0.0026 / 0.0164 / 0.0146, so these are
    % genuine regression checks rather than rubber stamps.
    tol_10s = 0.02; tol_tail = 0.02; tol_final = 0.02;

    [~, idx10] = min(abs(res.t - 10));
    assert(E_chi(idx10) <= tol_10s, ...
        'STEP 52: FAIL - E_chi=%.4e at t=%.3f exceeds %.4g at the combined 10 s horizon', ...
        E_chi(idx10), res.t(idx10), tol_10s);

    tail = res.t >= 10;
    max_tail = max(E_chi(tail));
    assert(max_tail <= tol_tail, ...
        'STEP 52: FAIL - max E_chi over [10,100]=%.4e exceeds %.4g', max_tail, tol_tail);

    assert(E_chi(end) <= tol_final, ...
        'STEP 52: FAIL - final E_chi=%.4e exceeds %.4g', E_chi(end), tol_final);

    % --- Actuator limits, force and moment checked SEPARATELY ------------
    sat_cfg = saturation_config();
    assert(isfield(manifest, 'max_tau_act_force') && isfield(manifest, 'max_tau_act_moment'), ...
        'STEP 52: FAIL - manifest lacks per-channel online actuator maxima');
    assert(manifest.max_tau_act_force <= sat_cfg.force_max + 1e-6, ...
        'STEP 52: FAIL - online force max %.4f exceeds %.1f N', manifest.max_tau_act_force, sat_cfg.force_max);
    assert(manifest.max_tau_act_moment <= sat_cfg.moment_max + 1e-6, ...
        'STEP 52: FAIL - online moment max %.4f exceeds %.1f Nm', manifest.max_tau_act_moment, sat_cfg.moment_max);

    % --- Explicitly NOT asserted, and why --------------------------------
    % The literal T1*=5 s reaching deadline is deliberately NOT a pass
    % criterion: the accepted dataset misses it (small-neighborhood entry is
    % observed ~7.1-7.5 s, sustained from 7.49 s). Asserting it would encode
    % a claim the project has formally withdrawn. Recorded here so its
    % absence reads as a decision, not an oversight.

    fprintf(['STEP 52: PASS (recomputed from raw result; cache agrees to %.1e; ' ...
        'E_chi@10s=%.4e, max[10,100]=%.4e, final=%.4e, force=%.2f/%.0fN, moment=%.2f/%.0fNm)\n'], ...
        cache_diff, E_chi(idx10), max_tail, E_chi(end), ...
        manifest.max_tau_act_force, sat_cfg.force_max, ...
        manifest.max_tau_act_moment, sat_cfg.moment_max);
end
