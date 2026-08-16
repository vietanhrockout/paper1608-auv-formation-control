function diagnose_stepC0b_checkpoint_resume_equivalence(t_final, t_mid, h)
    % DIAGNOSE_STEPC0B_CHECKPOINT_RESUME_EQUIVALENCE
    % Phase C.0 gate follow-up (P0 finding from the second GPT audit pass,
    % REVIEW_GPT_2026-08-16.md): proves the checkpoint/resume mechanism
    % added to projected_rk4_integrate.m produces a trajectory equivalent
    % (to floating-point roundoff) to an uninterrupted run, per the exact
    % acceptance test requested:
    %   1. Run an uninterrupted trajectory [0, t_final].
    %   2. Run [0, t_mid], writing a checkpoint along the way; start a
    %      FRESH state (simulating a fresh MATLAB process -- clear/reload)
    %      and resume [checkpoint.t, t_final] from that checkpoint.
    %   3. Compare final state, stored states at the checkpoint time, and
    %      integration statistics (max_retraction, total_retracted,
    %      nsteps) between the uninterrupted and resumed paths at
    %      roundoff-level tolerance.
    %   4. Checkpoint writes are already atomic (temp file + rename, see
    %      projected_rk4_integrate.m's local_save_checkpoint_atomic).

    addpath(genpath('paper1608'));

    if nargin < 1 || isempty(t_final)
        t_final = 0.6;
    end
    if nargin < 2 || isempty(t_mid)
        t_mid = 0.3;
    end
    if nargin < 3 || isempty(h)
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

    checkpoint_path = 'c0b_resume_test_checkpoint.mat';
    if exist(checkpoint_path, 'file')
        delete(checkpoint_path);
    end

    fprintf('=== [A] Uninterrupted run [0, %.4f] ===\n', t_final);
    opts_a = struct('store_stride', 1);
    [tA, XA, statsA] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_a);
    fprintf('  nsteps=%d, max_retraction=%.6e, total_retracted=%d\n', statsA.nsteps, statsA.max_retraction, statsA.total_retracted);

    fprintf('=== [B1] Checkpointed run [0, %.4f] (checkpoint_every_sec small enough to fire before t_mid) ===\n', t_mid);
    opts_b1 = struct('store_stride', 1, 'checkpoint_every_sec', t_mid / 3, 'checkpoint_path', checkpoint_path);
    [tB1, XB1, statsB1] = projected_rk4_integrate(t_mid, h, X0, params, sat_cfg, cfg, opts_b1);
    fprintf('  nsteps=%d, max_retraction=%.6e, total_retracted=%d\n', statsB1.nsteps, statsB1.max_retraction, statsB1.total_retracted);

    assert(exist(checkpoint_path, 'file') > 0, 'FAIL: no checkpoint file written during [B1]');

    fprintf('=== [B2] Reload checkpoint from disk (NOT from B1''s in-memory variables) and resume to %.4f ===\n', t_final);
    % NOTE: this drops the in-memory X0/XB1 references so [B2] is provably
    % driven only by what local_save_checkpoint_atomic actually persisted
    % to disk -- it does not spawn a literal separate MATLAB process (that
    % would need system()-level orchestration for marginal extra rigor
    % over what this already proves: the checkpoint FILE, not any
    % in-memory state, is sufficient to resume correctly).
    clear XA XB1 tA tB1; %#ok<CLEARVARS>
    d = load(checkpoint_path);
    checkpoint = d.checkpoint;
    fprintf('  loaded checkpoint: t=%.6f, k=%d/%d\n', checkpoint.t, checkpoint.k, checkpoint.nsteps);

    opts_b2 = struct('store_stride', 1, 'resume', checkpoint);
    [tB2, XB2, statsB2] = projected_rk4_integrate(t_final, h, checkpoint.X, params, sat_cfg, cfg, opts_b2);
    fprintf('  resumed segment [%.6f, %.6f], nsteps(cumulative)=%d, max_retraction(cumulative)=%.6e, total_retracted(cumulative)=%d\n', ...
        tB2(1), tB2(end), statsB2.nsteps, statsB2.max_retraction, statsB2.total_retracted);

    % Re-run A to get concrete arrays back in scope for comparison (the
    % 'clear' above was only meant to drop B1's in-memory state; re-derive
    % A's arrays by re-running -- deterministic, so this is just for the
    % comparison step, not re-testing anything new).
    [tA, XA, statsA] = projected_rk4_integrate(t_final, h, X0_reconstruct(cfg), params, sat_cfg, cfg, opts_a);

    fprintf('\n=== COMPARISON ===\n');

    % 1. Final state at t_final: uninterrupted vs resumed segment's last point.
    d_final = max(abs(XA(end,:) - XB2(end,:)));
    fprintf('max|X_A(t_final) - X_B2(t_final)| = %.6e\n', d_final);
    assert(d_final < 1e-9, 'FAIL: final states diverge beyond roundoff tolerance (%.6e >= 1e-9)', d_final);
    assert(abs(tA(end) - tB2(end)) < 1e-9, 'FAIL: final times do not match');

    % 2. State AT the checkpoint time: uninterrupted run's sample nearest
    %    checkpoint.t should equal checkpoint.X exactly (both are the same
    %    deterministic prefix computation from the same X0).
    [~, idxA] = min(abs(tA - checkpoint.t));
    d_checkpoint = max(abs(XA(idxA,:) - checkpoint.X(:).'));
    fprintf('max|X_A(checkpoint.t) - checkpoint.X| = %.6e (t_A=%.6f vs checkpoint.t=%.6f)\n', ...
        d_checkpoint, tA(idxA), checkpoint.t);
    assert(d_checkpoint < 1e-9, 'FAIL: state at checkpoint time diverges beyond roundoff tolerance');

    % 3. Cumulative integration statistics.
    fprintf('nsteps:          A=%d  B2(cumulative)=%d\n', statsA.nsteps, statsB2.nsteps);
    fprintf('max_retraction:  A=%.10e  B2(cumulative)=%.10e\n', statsA.max_retraction, statsB2.max_retraction);
    fprintf('total_retracted: A=%d  B2(cumulative)=%d\n', statsA.total_retracted, statsB2.total_retracted);
    assert(statsA.nsteps == statsB2.nsteps, 'FAIL: nsteps mismatch');
    assert(statsA.total_retracted == statsB2.total_retracted, 'FAIL: total_retracted mismatch (resume did not correctly seed/continue counting)');
    assert(abs(statsA.max_retraction - statsB2.max_retraction) < 1e-9, 'FAIL: max_retraction mismatch beyond roundoff');

    fprintf('\nPASS: checkpoint/resume produces a trajectory and cumulative statistics equivalent to an uninterrupted run, at roundoff-level tolerance.\n');

    delete(checkpoint_path);
    fprintf('=== END C.0b (checkpoint/resume equivalence CONFIRMED) ===\n');
end

function X0 = X0_reconstruct(cfg)
    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);
end
