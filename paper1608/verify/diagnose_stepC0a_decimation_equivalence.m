function diagnose_stepC0a_decimation_equivalence(t_final, h, stride)
    % DIAGNOSE_STEPC0A_DECIMATION_EQUIVALENCE
    % Phase C.0 gate follow-up (P1 finding from the second GPT audit pass):
    % the original C.0 regression test (run_c0_regression.m) only ran the
    % NEW (strided/checkpointed) integrator path with no archived baseline
    % and no numerical equality assertion -- it showed the new path
    % produces PLAUSIBLE output, not that it is IDENTICAL to the old
    % always-store-every-step behavior at the timestamps both paths share.
    %
    % This runs the SAME closed-loop trajectory 3 ways:
    %   (1) store_stride=1, no checkpointing (matches pre-C.0-gate behavior
    %       exactly -- this is the "old" baseline, reproduced via the new
    %       code's default opts).
    %   (2) store_stride=N (decimated), no checkpointing.
    %   (3) store_stride=N (decimated), WITH checkpointing enabled.
    % and asserts that at every timestamp (2) and (3) actually stored, the
    % state exactly matches (1)'s state at the same timestamp (to roundoff),
    % and that all three runs agree exactly on nsteps/max_retraction/
    % total_retracted (decimation and checkpointing must not change the
    % physics, only what gets recorded).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 0.5;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end
    if nargin < 3 || isempty(stride)
        stride = 7; % deliberately not a divisor of nsteps, to exercise the non-aligned-final-step path too
    end

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = simulation_params();

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    fprintf('=== (1) store_stride=1, no checkpoint (baseline) ===\n');
    [t1, X1, s1] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, struct('store_stride', 1));
    fprintf('  %d stored samples, nsteps=%d, max_retraction=%.10e, total_retracted=%d\n', numel(t1), s1.nsteps, s1.max_retraction, s1.total_retracted);

    fprintf('=== (2) store_stride=%d, no checkpoint ===\n', stride);
    [t2, X2, s2] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, struct('store_stride', stride));
    fprintf('  %d stored samples, nsteps=%d, max_retraction=%.10e, total_retracted=%d\n', numel(t2), s2.nsteps, s2.max_retraction, s2.total_retracted);

    ckpt_path = 'c0a_decimation_test_checkpoint.mat';
    if exist(ckpt_path, 'file'); delete(ckpt_path); end
    fprintf('=== (3) store_stride=%d, WITH checkpointing every %.3fs ===\n', stride, t_final/4);
    opts3 = struct('store_stride', stride, 'checkpoint_every_sec', t_final/4, 'checkpoint_path', ckpt_path);
    [t3, X3, s3] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts3);
    fprintf('  %d stored samples, nsteps=%d, max_retraction=%.10e, total_retracted=%d\n', numel(t3), s3.nsteps, s3.max_retraction, s3.total_retracted);
    assert(exist(ckpt_path, 'file') > 0, 'FAIL: (3) should have written a checkpoint');
    delete(ckpt_path);

    fprintf('\n=== COMPARISON ===\n');

    % Stats must match exactly across all three -- decimation/checkpointing
    % must not perturb the physics.
    assert(s1.nsteps == s2.nsteps && s2.nsteps == s3.nsteps, 'FAIL: nsteps differs across runs');
    assert(s1.total_retracted == s2.total_retracted && s2.total_retracted == s3.total_retracted, ...
        'FAIL: total_retracted differs across runs (decimation/checkpointing changed physics!)');
    assert(abs(s1.max_retraction - s2.max_retraction) < 1e-12 && abs(s2.max_retraction - s3.max_retraction) < 1e-12, ...
        'FAIL: max_retraction differs across runs beyond roundoff');
    fprintf('stats identical across (1)/(2)/(3): nsteps=%d, total_retracted=%d, max_retraction=%.10e -- PASS\n', ...
        s1.nsteps, s1.total_retracted, s1.max_retraction);

    % State-level: for every timestamp (2) stored, find the matching
    % timestamp in (1) and assert exact (roundoff) agreement.
    max_diff_2 = local_check_subset_matches(t1, X1, t2, X2, '(2) vs (1)');
    max_diff_3 = local_check_subset_matches(t1, X1, t3, X3, '(3) vs (1)');

    fprintf('\nmax state diff (2) vs (1) at common timestamps: %.6e\n', max_diff_2);
    fprintf('max state diff (3) vs (1) at common timestamps: %.6e\n', max_diff_3);
    assert(max_diff_2 < 1e-9, 'FAIL: decimated run (2) diverges from baseline (1) beyond roundoff');
    assert(max_diff_3 < 1e-9, 'FAIL: decimated+checkpointed run (3) diverges from baseline (1) beyond roundoff');

    fprintf('\nPASS: decimation and checkpointing produce EXACTLY the same physical trajectory as store_stride=1, verified at every shared timestamp, not just endpoints.\n');
    fprintf('=== END C.0a (decimation/checkpoint equivalence CONFIRMED) ===\n');
end

function max_diff = local_check_subset_matches(t_full, X_full, t_sub, X_sub, label)
    max_diff = 0;
    for i = 1:numel(t_sub)
        [dt, idx] = min(abs(t_full - t_sub(i)));
        assert(dt < 1e-9, '%s: timestamp %.6f in subset has no match in baseline (nearest dt=%.6e)', label, t_sub(i), dt);
        d = max(abs(X_full(idx,:) - X_sub(i,:)));
        max_diff = max(max_diff, d);
    end
end
