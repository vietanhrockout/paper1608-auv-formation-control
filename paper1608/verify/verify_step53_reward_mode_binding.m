function verify_step53_reward_mode_binding()
    % VERIFY_STEP53_REWARD_MODE_BINDING
    % Fail-closed binding of the Eq. (16) reward-signal decision.
    %
    % Added per REVIEW_GPT_2026-08-25_R16.md [P2]. Until now nothing in the
    % fast suite pinned WHICH reward mode production actually uses:
    % verify_step35b checks both candidate utilities numerically but is
    % deliberately mode-agnostic, and verify_step52 reads params straight
    % out of the artifact without comparing it to the live default. A
    % configuration drift, or swapping in a legacy tau_cmd_raw artifact,
    % would therefore have kept the suite green.
    %
    % The supervisor's determination (2026-08-18) is that Eq. (16)'s tau_i
    % is the physically applied, actuator-saturated input tau_act. This
    % oracle asserts that decision three ways:
    %   1. the live production default is 'tau_act_saturated';
    %   2. the committed Phase-C artifact was produced under that mode;
    %   3. artifact and live default agree with each other.
    % (3) is not redundant: it is what catches a future change that edits
    % both the default and this oracle's expectation but leaves a stale
    % dataset in place.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(project_root);
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'simulation'));

    expected = 'tau_act_saturated';

    % --- 1. Live production default -------------------------------------
    p = simulation_params();
    assert(isfield(p, 'critic_reward_tau_mode'), ...
        'STEP 53: FAIL - params has no critic_reward_tau_mode field');
    assert(strcmp(p.critic_reward_tau_mode, expected), ...
        ['STEP 53: FAIL - production default is ''%s'' but the supervisor determination ' ...
         'requires ''%s'' (Eq. 16 uses the saturated input). See Issue M in docs/HANDOFF.md.'], ...
        p.critic_reward_tau_mode, expected);

    % --- 2. Committed Phase-C artifact ----------------------------------
    paths = project_paths();
    result_path = fullfile(paths.phase_c, 'phase_c_result_t100.mat');
    assert(exist(result_path, 'file') == 2, ...
        'STEP 53: FAIL - missing committed artifact %s', result_path);
    d = load(result_path, 'res');
    assert(isfield(d.res, 'params') && isfield(d.res.params, 'critic_reward_tau_mode'), ...
        'STEP 53: FAIL - committed artifact records no critic_reward_tau_mode');
    artifact_mode = d.res.params.critic_reward_tau_mode;
    assert(strcmp(artifact_mode, expected), ...
        ['STEP 53: FAIL - committed Phase-C dataset was produced under ''%s'', not ''%s''. ' ...
         'It predates the Eq. (16) correction and must be regenerated.'], artifact_mode, expected);

    % --- 3. Artifact vs. live default -----------------------------------
    assert(strcmp(artifact_mode, p.critic_reward_tau_mode), ...
        ['STEP 53: FAIL - committed dataset mode ''%s'' does not match the current production ' ...
         'default ''%s''; the artifact no longer describes what production would produce.'], ...
        artifact_mode, p.critic_reward_tau_mode);

    fprintf('STEP 53: PASS (production default and committed Phase-C artifact both bound to ''%s'')\n', expected);
end
