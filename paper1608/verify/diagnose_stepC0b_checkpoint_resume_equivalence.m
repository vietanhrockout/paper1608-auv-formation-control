function diagnose_stepC0b_checkpoint_resume_equivalence(t_final, h, interrupt_step)
    % DIAGNOSE_STEPC0B_CHECKPOINT_RESUME_EQUIVALENCE (v2, round-2 audit fix)
    %
    % The v1 version of this test resumed by calling
    % projected_rk4_integrate directly, using a checkpoint written by a
    % SEPARATE, SHORTER run (target t_mid < t_final) -- a mismatch that
    % the actual production wrapper, resume_projected_rk4_run.m, would
    % correctly REJECT (checkpoint.nsteps for target t_mid does not equal
    % ceil(t_final/h)). So v1 proved the raw integrator's one-step-method
    % state continuation works, but never actually exercised the
    % production-facing wrapper or a realistic same-target interruption.
    %
    % This version:
    %   1. Runs an uninterrupted baseline [0, t_final] (store_stride=1).
    %   2. Runs a SEPARATE invocation with the SAME t_final target
    %      (matching a real production launch), but stops early via the
    %      opts.max_steps test hook -- simulating a crash/kill AFTER at
    %      least one checkpoint was written. nsteps (and hence
    %      checkpoint.nsteps/.t_final_target) correctly reflects the true
    %      t_final target throughout, exactly as a real interruption
    %      would leave it. The truncated in-memory output of this call is
    %      discarded (simulating that it was lost in the crash) -- only
    %      the checkpoint FILE survives.
    %   3. Calls resume_projected_rk4_run.m -- the actual production
    %      wrapper, not the raw integrator -- to resume to t_final.
    %   4. Compares the wrapper's FULL STITCHED [0,t_final] history (not
    %      just the tail segment) against the uninterrupted baseline at
    %      every shared timestamp, plus cumulative stats including the
    %      actuator maxima (which must carry forward across the crash,
    %      not reset to 0).
    %   5. Negative test: confirms the wrapper actually REJECTS a resume
    %      attempt with a mismatched t_final (config-binding fix).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 0.6;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end
    if nargin < 3 || isempty(interrupt_step)
        interrupt_step = round((t_final / h) * 0.4); % interrupt at ~40% of the way through
    end

    cfg = nn_config();
    sat_cfg = saturation_config();
    params = simulation_params();

    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

    checkpoint_path = 'c0b_resume_test_checkpoint.mat';
    if exist(checkpoint_path, 'file')
        delete(checkpoint_path);
    end
    tmp_path = [checkpoint_path '.tmp'];
    if exist(tmp_path, 'file')
        delete(tmp_path);
    end

    fprintf('=== [A] Uninterrupted baseline [0, %.4f] ===\n', t_final);
    opts_a = struct('store_stride', 1, 'track_actuator', true);
    [tA, XA, statsA] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_a);
    fprintf('  nsteps=%d, max_retraction=%.6e, total_retracted=%d, max_tau_act force=%.4f moment=%.4f\n', ...
        statsA.nsteps, statsA.max_retraction, statsA.total_retracted, statsA.max_tau_act_force, statsA.max_tau_act_moment);

    fprintf('=== [B] Same-target run [0, %.4f], simulated crash after step %d (opts.max_steps) ===\n', t_final, interrupt_step);
    opts_b = struct('store_stride', 1, 'track_actuator', true, ...
        'checkpoint_every_sec', (interrupt_step*h) / 3, 'checkpoint_path', checkpoint_path, ...
        'max_steps', interrupt_step);
    [tB_discarded, XB_discarded, statsB_discarded] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_b); %#ok<ASGLU>
    fprintf('  [B] stopped early as intended (simulated crash) at t=%.4f of %.4f -- this output is now DISCARDED, only the checkpoint file survives\n', ...
        tB_discarded(end), t_final);
    assert(exist(checkpoint_path, 'file') > 0, 'FAIL: no checkpoint file written during [B]');
    clear tB_discarded XB_discarded statsB_discarded opts_b; %#ok<CLEARVARS>

    fprintf('=== [C] Resume via the PRODUCTION wrapper resume_projected_rk4_run.m ===\n');
    res = resume_projected_rk4_run(checkpoint_path, t_final, h, params, sat_cfg, cfg);
    fprintf('  resumed: %d total stitched samples, covering [%.4f, %.4f]\n', numel(res.t), res.t(1), res.t(end));

    fprintf('\n=== COMPARISON ===\n');

    d_final = max(abs(XA(end,:) - res.X(end,:)));
    fprintf('max|X_A(t_final) - X_resumed(t_final)| = %.6e\n', d_final);
    assert(d_final < 1e-9, 'FAIL: final states diverge beyond roundoff tolerance (%.6e >= 1e-9)', d_final);
    assert(abs(tA(end) - res.t(end)) < 1e-9, 'FAIL: final times do not match');

    % Full-history comparison at every timestamp the resumed/stitched
    % history actually stored (should be every step, since both A and B
    % used store_stride=1).
    assert(numel(res.t) == numel(tA), ...
        'FAIL: stitched history has %d samples, baseline has %d -- stitching lost or duplicated samples', numel(res.t), numel(tA));
    max_diff = max(max(abs(XA - res.X)));
    fprintf('max|X_A - X_resumed| across ALL %d shared timestamps = %.6e\n', numel(tA), max_diff);
    assert(max_diff < 1e-9, 'FAIL: stitched full history diverges from baseline beyond roundoff tolerance');

    fprintf('nsteps:            A=%d  resumed(cumulative)=%d\n', statsA.nsteps, res.stats.nsteps);
    fprintf('max_retraction:    A=%.10e  resumed(cumulative)=%.10e\n', statsA.max_retraction, res.stats.max_retraction);
    fprintf('total_retracted:   A=%d  resumed(cumulative)=%d\n', statsA.total_retracted, res.stats.total_retracted);
    fprintf('max_tau_act force: A=%.6f  resumed(cumulative)=%.6f\n', statsA.max_tau_act_force, res.stats.max_tau_act_force);
    fprintf('max_tau_act moment:A=%.6f  resumed(cumulative)=%.6f\n', statsA.max_tau_act_moment, res.stats.max_tau_act_moment);
    assert(statsA.nsteps == res.stats.nsteps, 'FAIL: nsteps mismatch');
    assert(statsA.total_retracted == res.stats.total_retracted, 'FAIL: total_retracted mismatch');
    assert(abs(statsA.max_retraction - res.stats.max_retraction) < 1e-9, 'FAIL: max_retraction mismatch beyond roundoff');
    assert(abs(statsA.max_tau_act_force - res.stats.max_tau_act_force) < 1e-9, ...
        'FAIL: max_tau_act_force mismatch -- actuator peak not correctly carried forward across resume');
    assert(abs(statsA.max_tau_act_moment - res.stats.max_tau_act_moment) < 1e-9, ...
        'FAIL: max_tau_act_moment mismatch -- actuator peak not correctly carried forward across resume');

    fprintf('\nPASS: resume_projected_rk4_run.m produces a FULL stitched trajectory and cumulative statistics (including actuator maxima) equivalent to an uninterrupted run, at roundoff-level tolerance.\n');

    fprintf('\n=== [D] Negative test: wrapper must REJECT a mismatched-target resume ===\n');
    rejected = false;
    try
        resume_projected_rk4_run(checkpoint_path, t_final + 0.1, h, params, sat_cfg, cfg);
    catch ME
        rejected = true;
        fprintf('  correctly rejected with: %s\n', ME.message);
    end
    assert(rejected, 'FAIL: wrapper did NOT reject a resume with a mismatched t_final -- config-binding check is not working');
    fprintf('PASS: config-mismatch rejection confirmed.\n');

    delete(checkpoint_path);
    fprintf('=== END C.0b v2 (production wrapper checkpoint/resume equivalence CONFIRMED, including full history stitching, actuator-maxima carryover, and config-mismatch rejection) ===\n');
end
