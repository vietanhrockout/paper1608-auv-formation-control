function diagnose_stepC0c_multi_resume_equivalence(t_final, h)
    % DIAGNOSE_STEPC0C_MULTI_RESUME_EQUIVALENCE
    % Phase C.0 gate round-3 follow-up (P0 finding, third GPT audit pass):
    % the round-2/round-3 resume fix was only ever tested with a SINGLE
    % interruption. GPT correctly identified that a checkpoint written
    % DURING an already-resumed call only carried that call's own new
    % segment's history -- so a SECOND crash, resumed from THAT
    % checkpoint, would silently lose the original prefix. This test
    % proves the fix for exactly that scenario, per GPT's exact spec:
    %   1. Original launch, interrupted after checkpoint C1 (~1/3 through).
    %   2. Resume from C1 via the PRODUCTION WRAPPER, itself interrupted
    %      after writing checkpoint C2 (~2/3 through) -- using the
    %      wrapper's own max_steps test-hook passthrough, so this is a
    %      genuine second call to resume_projected_rk4_run.m, not the raw
    %      integrator.
    %   3. Resume from C2 via the production wrapper again, running to
    %      completion.
    %   4. Compare the final stitched [0,t_final] history and all
    %      cumulative statistics against an uninterrupted baseline, at
    %      EVERY stored timestamp -- not just the endpoint.
    % All in-memory histories are discarded at both interruption
    % boundaries, so only what's actually persisted to the checkpoint
    % files is available for each subsequent resume (same discipline as
    % diagnose_stepC0b_*).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 0.9;
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

    ckpt_path = 'c0c_multiresume_test_checkpoint.mat';
    if exist(ckpt_path, 'file'); delete(ckpt_path); end
    if exist([ckpt_path '.tmp'], 'file'); delete([ckpt_path '.tmp']); end

    nsteps_total = ceil(t_final / h);
    interrupt1_step = round(nsteps_total * 0.33);
    interrupt2_step_from_c1 = round(nsteps_total * 0.33); % roughly another 1/3 of the total, measured from wherever C1 landed

    fprintf('=== [A] Uninterrupted baseline [0, %.4f] ===\n', t_final);
    opts_a = struct('store_stride', 1, 'track_actuator', true);
    [tA, XA, statsA] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_a);
    fprintf('  nsteps=%d, max_retraction=%.6e, total_retracted=%d, max_tau_act force=%.4f moment=%.4f\n', ...
        statsA.nsteps, statsA.max_retraction, statsA.total_retracted, statsA.max_tau_act_force, statsA.max_tau_act_moment);

    fprintf('=== [B] Original launch [0, %.4f], simulated crash #1 after step %d -> checkpoint C1 ===\n', t_final, interrupt1_step);
    opts_b = struct('store_stride', 1, 'track_actuator', true, ...
        'checkpoint_every_sec', (interrupt1_step*h) / 3, 'checkpoint_path', ckpt_path, ...
        'max_steps', interrupt1_step);
    [tB, XB, statsB] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_b); %#ok<ASGLU>
    fprintf('  [B] stopped at t=%.4f (simulated crash #1) -- DISCARDED, only checkpoint C1 survives\n', tB(end));
    assert(exist(ckpt_path, 'file') > 0, 'FAIL: no checkpoint C1 written during [B]');
    clear tB XB statsB opts_b; %#ok<CLEARVARS>

    fprintf('=== [C] Resume #1 via production wrapper, simulated crash #2 after %d more steps -> checkpoint C2 ===\n', interrupt2_step_from_c1);
    % checkpoint_every_sec overridden short (production default is 10s of
    % SIMULATED time, which would never fire within this test's ~0.3s
    % resume window) so a second checkpoint actually gets written for
    % this test to interrupt at.
    resC = resume_projected_rk4_run(ckpt_path, t_final, h, params, sat_cfg, cfg, [], false, ...
        interrupt2_step_from_c1, (interrupt2_step_from_c1*h) / 3); %#ok<NASGU>
    fprintf('  [C] resume #1 stopped at t=%.4f (simulated crash #2) -- DISCARDED, only checkpoint C2 (overwritten in place) survives\n', resC.t(end));
    clear resC; %#ok<CLEARVARS>

    fprintf('=== [D] Resume #2 via production wrapper, runs to completion ===\n');
    res = resume_projected_rk4_run(ckpt_path, t_final, h, params, sat_cfg, cfg);
    fprintf('  [D] final: %d total stitched samples covering [%.4f, %.4f]\n', numel(res.t), res.t(1), res.t(end));

    fprintf('\n=== COMPARISON ===\n');

    assert(abs(res.t(1) - 0) < 1e-9, 'FAIL: stitched history does not start at t=0 -- original [0,t1] prefix was lost across the resume chain');
    assert(numel(res.t) == numel(tA), 'FAIL: stitched history has %d samples, baseline has %d', numel(res.t), numel(tA));

    max_diff = max(max(abs(XA - res.X)));
    fprintf('max|X_A - X_resumed_twice| across ALL %d shared timestamps = %.6e\n', numel(tA), max_diff);
    assert(max_diff < 1e-9, 'FAIL: twice-resumed full history diverges from baseline beyond roundoff tolerance');

    fprintf('nsteps:            A=%d  twice-resumed(cumulative)=%d\n', statsA.nsteps, res.stats.nsteps);
    fprintf('max_retraction:    A=%.10e  twice-resumed(cumulative)=%.10e\n', statsA.max_retraction, res.stats.max_retraction);
    fprintf('total_retracted:   A=%d  twice-resumed(cumulative)=%d\n', statsA.total_retracted, res.stats.total_retracted);
    fprintf('max_tau_act force: A=%.6f  twice-resumed(cumulative)=%.6f\n', statsA.max_tau_act_force, res.stats.max_tau_act_force);
    fprintf('max_tau_act moment:A=%.6f  twice-resumed(cumulative)=%.6f\n', statsA.max_tau_act_moment, res.stats.max_tau_act_moment);
    assert(statsA.nsteps == res.stats.nsteps, 'FAIL: nsteps mismatch');
    assert(statsA.total_retracted == res.stats.total_retracted, 'FAIL: total_retracted mismatch across the resume chain');
    assert(abs(statsA.max_retraction - res.stats.max_retraction) < 1e-9, 'FAIL: max_retraction mismatch beyond roundoff');
    assert(abs(statsA.max_tau_act_force - res.stats.max_tau_act_force) < 1e-9, 'FAIL: max_tau_act_force not correctly carried across TWO resumes');
    assert(abs(statsA.max_tau_act_moment - res.stats.max_tau_act_moment) < 1e-9, 'FAIL: max_tau_act_moment not correctly carried across TWO resumes');

    fprintf('\nPASS: a chain of TWO interruptions, both resumed through the production wrapper, produces a FULL stitched trajectory and cumulative statistics equivalent to an uninterrupted run, at roundoff-level tolerance -- the original [0,t1] prefix survives the second crash.\n');

    delete(ckpt_path);
    fprintf('=== END C.0c (multi-resume equivalence CONFIRMED for a two-interruption chain) ===\n');
end
