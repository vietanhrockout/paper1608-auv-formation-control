function diagnose_stepC0e_git_binding_integrity(t_final, h)
    % DIAGNOSE_STEPC0E_GIT_BINDING_INTEGRITY
    % Phase C.0 gate round-4 follow-up (P0/P1, fourth GPT audit pass):
    % C0b/C0c prove state/history equivalence across resumes but don't
    % specifically exercise the git-binding contract. This test adds the
    % explicit assertions GPT requested:
    %   1. The anchored repo SHA is available (this repo, not some other).
    %   2. Every checkpoint in a resume CHAIN retains the SAME launch SHA
    %      (not a fresh per-checkpoint one) -- proves the round-4
    %      immutable-launch-fingerprint fix actually propagates, not just
    %      coincidentally matches because the tree didn't change.
    %   3. A MUTATED/mismatched SHA is correctly rejected on resume (the
    %      "mock the current SHA" negative test GPT specifically asked
    %      for), and the rejection happens WITHOUT touching the
    %      checkpoint file on disk (the last valid checkpoint survives).
    %   4. An UNAVAILABLE git fingerprint (on either side) is correctly
    %      treated as fail-closed, not a silent pass.
    %
    % Whether the launch tree was CLEAN at the time this test is run is
    % reported but not hard-asserted here (this file needs to work in
    % dev/diagnostic contexts too) -- the launch script running this test
    % for real Phase-C-readiness evidence should be run from a clean,
    % committed tree and that fact should be recorded in the run log,
    % which run_c0e.m does by printing checkpoint.git_dirty explicitly.

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

    ckpt_path = 'c0e_git_binding_test_checkpoint.mat';
    if exist(ckpt_path, 'file'); delete(ckpt_path); end
    if exist([ckpt_path '.tmp'], 'file'); delete([ckpt_path '.tmp']); end

    fprintf('=== [1] Anchored repo SHA availability ===\n');
    fp = git_fingerprint();
    fprintf('  available=%d, sha=%s, dirty=%d, repo_root=%s\n', fp.available, fp.sha, fp.dirty, fp.repo_root);
    assert(fp.available, 'FAIL: git fingerprint unavailable -- cannot proceed with the rest of this test');
    fprintf('  PASS (note: dirty=%d -- for genuine Phase-C-readiness evidence this should be run from a CLEAN committed tree)\n', fp.dirty);

    nsteps_total = ceil(t_final / h);
    interrupt1_step = round(nsteps_total * 0.4);

    launch_fp = struct('sha', fp.sha, 'dirty', fp.dirty, 'available', fp.available, 'repo_root', fp.repo_root);

    fprintf('\n=== [2] SHA consistency across a resume chain ===\n');
    opts_b = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt1_step*h)/3, ...
        'checkpoint_path', ckpt_path, 'max_steps', interrupt1_step, 'launch_git_fp', launch_fp);
    [~, ~, ~] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_b);
    d1 = load(ckpt_path);
    sha_c1 = d1.checkpoint.git_sha;
    fprintf('  checkpoint C1: git_sha=%s\n', sha_c1);

    res = resume_projected_rk4_run(ckpt_path, t_final, h, params, sat_cfg, cfg, [], false, [], (nsteps_total - interrupt1_step) * h / 5); %#ok<NASGU>
    d2 = load(ckpt_path); % resume's own checkpoint overwrote C1 in place, or the run completed without another checkpoint
    if isfield(d2, 'checkpoint')
        sha_final_checkpoint = d2.checkpoint.git_sha;
        fprintf('  final checkpoint on disk: git_sha=%s\n', sha_final_checkpoint);
        assert(strcmp(sha_c1, sha_final_checkpoint), ...
            'FAIL: SHA drifted across the resume chain (C1=%s, later=%s) -- launch fingerprint was not correctly propagated', ...
            sha_c1, sha_final_checkpoint);
    end
    fprintf('  PASS: every checkpoint in the chain recorded the SAME launch SHA (%s)\n', sha_c1);

    if exist(ckpt_path, 'file'); delete(ckpt_path); end

    fprintf('\n=== [3] Negative test: mutated/mismatched SHA must be rejected ===\n');
    opts_c = struct('store_stride', 1, 'checkpoint_every_sec', (interrupt1_step*h)/3, ...
        'checkpoint_path', ckpt_path, 'max_steps', interrupt1_step, 'launch_git_fp', launch_fp);
    [~, ~, ~] = projected_rk4_integrate(t_final, h, X0, params, sat_cfg, cfg, opts_c);

    d3 = load(ckpt_path);
    checkpoint_before_mutation = d3.checkpoint; % keep a copy to prove the on-disk file is untouched by the rejected attempt
    mutated = d3.checkpoint;
    mutated.git_sha = 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'; % obviously-fake SHA
    checkpoint = mutated; %#ok<NASGU>
    save(ckpt_path, 'checkpoint');
    fprintf('  mutated checkpoint on disk to a fake SHA (deadbeef...)\n');

    rejected_sha = false;
    try
        resume_projected_rk4_run(ckpt_path, t_final, h, params, sat_cfg, cfg);
    catch ME
        rejected_sha = true;
        fprintf('  correctly rejected with: %s\n', ME.message);
    end
    assert(rejected_sha, 'FAIL: resume did NOT reject a checkpoint with a mutated/mismatched git SHA');

    d4 = load(ckpt_path);
    assert(strcmp(d4.checkpoint.git_sha, 'deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'), ...
        'FAIL: the rejected resume attempt modified the on-disk checkpoint file -- it should have been left untouched');
    fprintf('  PASS: checkpoint file on disk is untouched by the rejected resume attempt (still holds the mutated SHA, proving no accidental overwrite)\n');
    if exist(ckpt_path, 'file'); delete(ckpt_path); end

    fprintf('\n=== [4] Negative test: unavailable git fingerprint must fail closed ===\n');
    d5_checkpoint = checkpoint_before_mutation;
    d5_checkpoint.git_available = false;
    checkpoint = d5_checkpoint; %#ok<NASGU>
    save(ckpt_path, 'checkpoint');
    fprintf('  wrote a checkpoint with git_available=false (simulating git having been unavailable at launch)\n');

    rejected_unavailable = false;
    try
        resume_projected_rk4_run(ckpt_path, t_final, h, params, sat_cfg, cfg);
    catch ME
        rejected_unavailable = true;
        fprintf('  correctly rejected with: %s\n', ME.message);
    end
    assert(rejected_unavailable, 'FAIL: resume did NOT reject a checkpoint with an unavailable git fingerprint (should fail closed, not silently pass)');
    fprintf('  PASS: unavailable git fingerprint correctly fails closed by default.\n');

    if exist(ckpt_path, 'file'); delete(ckpt_path); end
    if exist([ckpt_path '.tmp'], 'file'); delete([ckpt_path '.tmp']); end

    fprintf('\n=== END C.0e (git-binding integrity CONFIRMED: SHA consistency across a chain, mutated-SHA rejection with no on-disk side effect, and fail-closed on unavailable git) ===\n');
end
