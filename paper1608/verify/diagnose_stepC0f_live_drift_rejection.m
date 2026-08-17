function diagnose_stepC0f_live_drift_rejection(t_final, h)
    % DIAGNOSE_STEPC0F_LIVE_DRIFT_REJECTION
    % Phase C.0 gate round-5 follow-up (P0/P1, sixth GPT audit pass,
    % REVIEW_GPT_2026-08-17_R5.md): C0e only mutated SAVED checkpoint
    % fields (static, post-hoc) -- it never simulated the two LIVE
    % failure modes that round 5's own fix turned out to still fail open
    % on: (a) git becoming unavailable DURING a run, and (b) the working
    % tree becoming dirty (an uncommitted edit, SHA unchanged) between a
    % checkpoint and a resume. This test exercises exactly GPT's 4
    % requested scenarios, using the injectable mock-fingerprint test
    % seams added to projected_rk4_integrate.m (opts.mock_current_git_fp_fn)
    % and resume_projected_rk4_run.m (mock_current_git_fp) -- per GPT's
    % explicit request to use "an injectable fingerprint provider or a
    % narrow test seam rather than modifying the real repository mid-test."
    %
    % Scenario 1: clean launch FP + mocked current UNAVAILABLE at a
    %             checkpoint boundary -> abort BEFORE overwriting the
    %             last valid checkpoint.
    % Scenario 2: clean saved checkpoint + mocked current SAME SHA but
    %             DIRTY=true -> resume REJECTS before
    %             projected_rk4_integrate is ever called (no integration
    %             work happens).
    % Scenario 3: clean launch FP + mocked current SAME SHA but
    %             DIRTY=true at a checkpoint boundary DURING a resumed
    %             segment -> abort BEFORE overwriting the last valid
    %             checkpoint (this is the "drift only shows up at the
    %             NEXT checkpoint" gap from finding #2, now covered end
    %             to end: the resume-time check in scenario 2 covers
    %             "before the first step"; this covers "mid-segment,
    %             caught before it can silently taint further steps").
    % Scenario 4: UNCHANGED clean fingerprint (real git, no mocking) ->
    %             checkpoint/resume still pass bit-exact (sanity check
    %             that the fail-closed fixes did not break the happy path).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 0.6;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = simulation_params();

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    real_fp = git_fingerprint();
    assert(real_fp.available, 'FAIL: git fingerprint unavailable -- cannot proceed with this test');
    fprintf('Real fingerprint for this test run: sha=%s dirty=%d\n\n', real_fp.sha, real_fp.dirty);

    nsteps_total = ceil(t_final / h);
    interrupt_step = round(nsteps_total * 0.4);

    % ===================================================================
    fprintf('=== [1] Mocked current UNAVAILABLE at a checkpoint boundary mid-resume ===\n');
    ckpt1 = 'c0f_scenario1_checkpoint.mat';
    if exist(ckpt1, 'file'); delete(ckpt1); end

    launch_fp = struct('sha', real_fp.sha, 'dirty', real_fp.dirty, 'available', true, 'repo_root', real_fp.repo_root);
    opts_a = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt1, 'max_steps', interrupt_step, 'launch_git_fp', launch_fp);
    projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_a);
    assert(exist(ckpt1, 'file') > 0, 'FAIL: [1] setup -- no valid checkpoint produced');
    d1_before = load(ckpt1);
    fprintf('  valid checkpoint produced: t=%.4f, git_sha=%s\n', d1_before.checkpoint.t, d1_before.checkpoint.git_sha);

    mock_unavailable = @() struct('sha', 'unknown', 'dirty', true, 'available', false, 'repo_root', real_fp.repo_root);
    opts_b = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt1, 'resume', d1_before.checkpoint, 'launch_git_fp', launch_fp, ...
        'mock_current_git_fp_fn', mock_unavailable);

    rejected1 = false;
    try
        projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_b);
    catch ME
        rejected1 = true;
        fprintf('  correctly ABORTED with: %s\n', ME.message);
    end
    assert(rejected1, 'FAIL: [1] did not abort when the current git fingerprint became unavailable mid-run');

    d1_after = load(ckpt1);
    assert(isequal(d1_before.checkpoint.t, d1_after.checkpoint.t) && strcmp(d1_before.checkpoint.git_sha, d1_after.checkpoint.git_sha), ...
        'FAIL: [1] the last valid checkpoint was modified despite the abort');
    fprintf('  PASS: last valid checkpoint on disk is untouched (still t=%.4f)\n\n', d1_after.checkpoint.t);
    delete(ckpt1);

    % ===================================================================
    fprintf('=== [2] Resume-time: same SHA but mocked current DIRTY=true ===\n');
    ckpt2 = 'c0f_scenario2_checkpoint.mat';
    if exist(ckpt2, 'file'); delete(ckpt2); end
    opts_c = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt2, 'max_steps', interrupt_step, 'launch_git_fp', launch_fp);
    projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_c);
    assert(exist(ckpt2, 'file') > 0, 'FAIL: [2] setup -- no valid checkpoint produced');

    mock_dirty = struct('sha', real_fp.sha, 'dirty', ~real_fp.dirty, 'available', true, 'repo_root', real_fp.repo_root);
    rejected2 = false;
    try
        resume_projected_rk4_run(ckpt2, t_final, h, params, sat_cfg, cfg, [], false, [], 10, mock_dirty);
    catch ME
        rejected2 = true;
        fprintf('  correctly REJECTED before any integration with: %s\n', ME.message);
    end
    assert(rejected2, 'FAIL: [2] resume did not reject a same-SHA-but-dirty-mismatched current fingerprint');
    fprintf('  PASS: dirty-state mismatch caught at resume time, before the first resumed RK4 step.\n\n');
    delete(ckpt2);

    % ===================================================================
    fprintf('=== [3] Mid-resumed-segment checkpoint: same SHA but mocked current DIRTY=true ===\n');
    ckpt3 = 'c0f_scenario3_checkpoint.mat';
    if exist(ckpt3, 'file'); delete(ckpt3); end
    opts_d = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt3, 'max_steps', interrupt_step, 'launch_git_fp', launch_fp);
    projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_d);
    d3_before = load(ckpt3);

    mock_dirty_fn = @() struct('sha', real_fp.sha, 'dirty', ~real_fp.dirty, 'available', true, 'repo_root', real_fp.repo_root);
    opts_e = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt3, 'resume', d3_before.checkpoint, 'launch_git_fp', launch_fp, ...
        'mock_current_git_fp_fn', mock_dirty_fn);

    rejected3 = false;
    try
        projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_e);
    catch ME
        rejected3 = true;
        fprintf('  correctly ABORTED with: %s\n', ME.message);
    end
    assert(rejected3, 'FAIL: [3] did not abort when the working tree became dirty (SHA unchanged) mid-resumed-segment');

    d3_after = load(ckpt3);
    assert(isequal(d3_before.checkpoint.t, d3_after.checkpoint.t), ...
        'FAIL: [3] the last valid checkpoint was modified despite the abort');
    fprintf('  PASS: last valid checkpoint on disk is untouched (still t=%.4f)\n\n', d3_after.checkpoint.t);
    delete(ckpt3);

    % ===================================================================
    fprintf('=== [4] Sanity: UNCHANGED clean fingerprint (real git, no mocking) still passes bit-exact ===\n');
    ckpt4 = 'c0f_scenario4_checkpoint.mat';
    if exist(ckpt4, 'file'); delete(ckpt4); end

    [tA, XA, statsA] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, struct('store_stride', 1));

    opts_f = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt_step*h)/3, ...
        'checkpoint_path', ckpt4, 'max_steps', interrupt_step, 'launch_git_fp', launch_fp);
    projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_f);
    res4 = resume_projected_rk4_run(ckpt4, t_final, h, params, sat_cfg, cfg);

    d_final = max(abs(XA(end,:) - res4.X(end,:)));
    fprintf('  max|X_A - X_resumed| at t_final = %.6e\n', d_final);
    assert(d_final < 1e-9, 'FAIL: [4] unchanged-fingerprint resume diverges from baseline beyond roundoff -- the fail-closed fixes broke the happy path');
    assert(statsA.nsteps == res4.stats.nsteps, 'FAIL: [4] nsteps mismatch on the happy path');
    fprintf('  PASS: happy path (unchanged fingerprint) remains bit-exact after the fail-closed fixes.\n');
    delete(ckpt4);

    fprintf('\n=== END C.0f (all 4 live-drift scenarios CONFIRMED: fail-closed on live unavailability and live dirty-drift, both at checkpoint time and resume time, with the happy path unaffected) ===\n');
end
