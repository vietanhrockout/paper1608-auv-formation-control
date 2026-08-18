function verify_step52_performance_criteria()
    % VERIFY_STEP52_PERFORMANCE_CRITERIA
    % Scientific regression oracle for the accepted 100 s Phase-C result.
    %
    % REWRITTEN after REVIEW_GPT_2026-08-18_R12.md [P1]. The previous
    % version was a FALSE ORACLE: its header advertised four criteria
    % (steady-state position error after 10 s, steady-state attitude error
    % after 10 s, sliding surface reaching its neighborhood before
    % T1*=5 s, actuator bounds), but the body ran
    % `exp4_rl_pts_mc(0.5, ...)` -- a 0.5 s simulation on the legacy,
    % known-stalling ode45 path -- and then checked ONLY the actuator
    % bounds, at a single final sample. Criteria 1-3 were never evaluated
    % by any line of code. Worse, criterion 3 asserted the literal
    % T1*=5 s reaching deadline, which the accepted Phase-C evidence shows
    % is MISSED (REVIEW_GPT_2026-08-17_R8.md; E_chi=4.93, E_s=542.6 at
    % t~5 s). So had it ever run its advertised checks, it would have
    % contradicted the project's own accepted findings.
    %
    % It now reads the COMMITTED Phase-C artifacts instead of simulating.
    % That makes the 100 s scientific assertions runnable in seconds, in
    % the fast block, without repeating a ~3.3 hour production run and
    % without touching the legacy ode45 path.
    %
    % Criteria asserted here are the ones the project actually accepts
    % (see handoff.md's Phase C section and analyze_phase_c_result.m):
    %   1. Tracking neighborhood entered by the COMBINED horizon
    %      T1*+T2* = 10 s -- NOT by T1* = 5 s.
    %   2. Full-tail boundedness of E_chi over [10, 100] s.
    %   3. Bounded final E_chi at t = 100 s.
    %   4. Actuator force and moment limits, checked SEPARATELY
    %      (150 N / 30 N*m) against the online every-step manifest maxima.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    repo_root = fileparts(project_root);

    analysis_path = fullfile(repo_root, 'phase_c_analysis_t100.mat');
    manifest_path = fullfile(repo_root, 'phase_c_manifest_t100.mat');
    if exist(analysis_path, 'file') ~= 2
        error('STEP 52: FAIL - missing committed artifact %s', analysis_path);
    end
    if exist(manifest_path, 'file') ~= 2
        error('STEP 52: FAIL - missing committed artifact %s', manifest_path);
    end

    da = load(analysis_path);
    dm = load(manifest_path);
    a = da.analysis;
    manifest = dm.manifest;

    t = a.t;
    E_chi = a.E_chi;

    assert(~any(isnan(E_chi)) && ~any(isinf(E_chi)), 'STEP 52: FAIL - non-finite E_chi in committed analysis');
    assert(abs(t(end) - 100) < 1e-6, 'STEP 52: FAIL - artifact horizon is %.4f s, expected 100 s', t(end));

    % Declared tolerances (mirrors analyze_phase_c_result.m; real margin
    % above the observed 0.0026 / 0.0164 / 0.0146 so these are genuine
    % regression checks rather than rubber stamps).
    tol_10s = 0.02;
    tol_tail = 0.02;
    tol_final = 0.02;

    % --- 1. Neighborhood entry by the COMBINED T1*+T2* = 10 s horizon ---
    [~, idx10] = min(abs(t - 10));
    assert(E_chi(idx10) <= tol_10s, ...
        'STEP 52: FAIL - E_chi=%.4e at t=%.3f exceeds %.4g at the combined 10 s horizon', ...
        E_chi(idx10), t(idx10), tol_10s);

    % --- 2. Full-tail boundedness over [10, 100] s ---
    tail = t >= 10;
    max_tail = max(E_chi(tail));
    assert(max_tail <= tol_tail, ...
        'STEP 52: FAIL - max E_chi over [10,100]=%.4e exceeds %.4g', max_tail, tol_tail);

    % --- 3. Bounded final error ---
    assert(E_chi(end) <= tol_final, ...
        'STEP 52: FAIL - final E_chi=%.4e exceeds %.4g', E_chi(end), tol_final);

    % --- 4. Actuator limits, force and moment checked SEPARATELY ---
    sat_cfg = saturation_config();
    assert(isfield(manifest, 'max_tau_act_force') && isfield(manifest, 'max_tau_act_moment'), ...
        'STEP 52: FAIL - manifest lacks per-channel online actuator maxima');
    assert(manifest.max_tau_act_force <= sat_cfg.force_max + 1e-6, ...
        'STEP 52: FAIL - online force max %.4f exceeds %.1f N', manifest.max_tau_act_force, sat_cfg.force_max);
    assert(manifest.max_tau_act_moment <= sat_cfg.moment_max + 1e-6, ...
        'STEP 52: FAIL - online moment max %.4f exceeds %.1f Nm', manifest.max_tau_act_moment, sat_cfg.moment_max);

    % --- Explicitly NOT asserted, and why ---
    % The literal T1*=5 s reaching deadline is deliberately NOT a pass
    % criterion: the accepted dataset misses it (small-neighborhood entry
    % is observed ~7.1-7.5 s, sustained from 7.49 s). Asserting it would
    % encode a claim the project has formally withdrawn. Recorded here so
    % its absence reads as a decision, not an oversight.

    fprintf(['STEP 52: PASS (artifact-based; E_chi@10s=%.4e, max[10,100]=%.4e, final=%.4e, ' ...
        'force=%.2f/%.0fN, moment=%.2f/%.0fNm)\n'], ...
        E_chi(idx10), max_tail, E_chi(end), ...
        manifest.max_tau_act_force, sat_cfg.force_max, ...
        manifest.max_tau_act_moment, sat_cfg.moment_max);
end
