function results = run_all_verifications(include_integration)
    % RUN_ALL_VERIFICATIONS Master runner for the verify_step*.m oracle suite.
    %
    % include_integration (default false): also run the oracles that
    %   integrate a trajectory. See the Issue K note below before enabling.
    %
    % CHANGES MADE DURING THE POST-R11 FULL-PROJECT AUDIT
    % -------------------------------------------------------------------
    % This was previously a SCRIPT that ran a hand-picked subset of 15
    % oracles, printed a summary, and ALWAYS exited 0 -- a failing test
    % produced console text but no nonzero exit status, so `matlab -batch`
    % could not detect it and nothing automated could gate on this file.
    % Three concrete problems fixed here:
    %   1. It now ERRORS when any oracle fails, so exit status is meaningful.
    %   2. The fast (algebra-level) and slow (integration-level) blocks are
    %      separated, because the integration block does not terminate on
    %      this system -- see Issue K below.
    %   3. It now returns a structured per-test result instead of only
    %      printing, so callers can inspect what ran.
    %
    % ISSUE K GATING (why include_integration defaults to false)
    % -------------------------------------------------------------------
    % Oracles that integrate a trajectory invoke ode45-based paths. Those
    % are exactly the paths Issue K proved cannot complete here: ode45, the
    % K.5 hybrid hot/cold split, and ode15s all stall near the critic-weight
    % projection boundary; only the fixed-step Projected RK4 production path
    % completes. Two audit runs confirmed the stall is current, not
    % historical: a full-suite sweep reached verify_step22 in seconds then
    % made no progress at verify_step23 for over half an hour, and this
    % runner's own previous (subset) form reached STEP 43 and then hung on
    % the integration tests behind it. Both were killed, not completed.
    %
    % So the default block is the one that actually terminates. Integration
    % oracles are NOT known-passing and are NOT silently omitted -- they are
    % listed explicitly and reported as SKIPPED with this reason.

    if nargin < 1 || isempty(include_integration)
        include_integration = false;
    end

    project_root = fileparts(mfilename('fullpath'));
    addpath(genpath(project_root));

    % Algebra//function-level oracles: pure evaluations, complete in seconds.
    fast_tests = {
        'verify_step01_structure'
        'verify_step02_notation'
        'verify_step03_audit'
        'verify_step04_paper_params'
        'verify_step05_derived_params'
        'verify_step05c_simulation_branch_propagation'
        'verify_step06_sigpow'
        'verify_step07_negative_power'
        'verify_step08_reference'
        'verify_step09_initial_conditions'
        'verify_step10_auv_params'
        'verify_step11_jacobian'
        'verify_step12_auv_plant'
        'verify_step13_earth_frame_consistency'
        'verify_step14_disturbance'
        'verify_step15_formation_error'
        'verify_step16_gain_L'
        'verify_step17_Ltilde_Lambda1'
        'verify_step18_sliding_surface'
        'verify_step19_f_true'
        'verify_step20_reaching_term'
        'verify_step25_saturation'
        'verify_step26_sat_limits'
        'verify_step27_antiwindup'
        'verify_step28_rbf'
        'verify_step29_nn_config'
        'verify_step30_actor_basis'
        'verify_step31_actor_output'
        'verify_step32_projection'
        'verify_step32b_unpack_state_transparency'
        'verify_step33_critic_basis'
        'verify_step34_critic_output'
        'verify_step35_utility'
        'verify_step35b_critic_control_cost_signal'
        'verify_step36_bellman_error'
        'verify_step37_critic_update'
        'verify_step38_actor_error'
        'verify_step39_actor_update'
        'verify_step40_controller_rl'
        'verify_step42_state_packing'
        'verify_step43_rhs_3auv_rl'
        'verify_step22_controller_mb'   % evidence: completed in seconds during the audit sweep
        'verify_step41_sat_antiwindup_loop' % R12 [P1]: one controller evaluation, NO integration
        'verify_step52_performance_criteria' % R12 [P1]: rewritten artifact-based, no simulation
        'verify_step69_plots'           % surface-only check, does not re-render (see its header)
        'verify_step72_tuning'
    };

    % Deferred oracles, each with its OWN reason. A single blanket
    % "Issue K" label was factually wrong (REVIEW_GPT_2026-08-18_R12.md
    % [P1]): most of these contain no critic weights at all, so the
    % critic-projection-boundary mechanism cannot be their cause. Columns:
    % {name, class, reason}.
    %   stalling-rl   -- genuine Issue K: adaptive solver + RL/critic dynamics.
    %   slow-mb       -- model-based/conventional, no critic. Expensive, and
    %                    step23 was observed non-terminating, but the CAUSE
    %                    is not established -- explicitly not attributed to
    %                    Issue K.
    %   slow-valid    -- production projected-RK4 path; valid, just costly.
    %   invalidated   -- targets a path the project already invalidated.
    deferred_tests = {
        'verify_step23_single_auv_mb',              'slow-mb',     'ode15s on rhs_single_auv_mb (model-based, no critic); observed non-terminating in the audit sweep, cause NOT established'
        'verify_step24_3auv_mb',                    'slow-mb',     'ode15s, 3-AUV model-based (no critic weights)'
        'verify_step44_numerical_stability',        'stalling-rl', 'ode45 on rhs_3auv_rl -- adaptive solver + critic dynamics, genuine Issue K'
        'verify_step45_exp0',                       'slow-mb',     'exp0_ideal_mb, model-based (no critic)'
        'verify_step46_exp1',                       'slow-mb',     'exp1_disturbed_mb, model-based (no critic)'
        'verify_step47_exp2',                       'slow-mb',     'exp2_sat_no_antiwindup, model-based (no critic)'
        'verify_step48_exp3',                       'slow-mb',     'exp3_sat_antiwindup, model-based (no critic)'
        'verify_step49_exp4',                       'stalling-rl', 'exp4_rl_pts_mc = legacy ode45 RL path, genuine Issue K'
        'verify_step50_exp5',                       'slow-mb',     'exp5_comparison_smc, conventional SMC (no critic)'
        'verify_step51_exp_runner',                 'stalling-rl', 'run_all_experiments includes the exp4 ode45 RL path'
        'verify_step55_pt_validation',              'slow-mb',     'sweep_initial_conditions -- repeated trajectory sweeps'
        'verify_phase_b1_behavioral_sanity',        'stalling-rl', 'exp4_rl_pts_mc = legacy ode45 RL path, genuine Issue K'
        'verify_phase_b2_hybrid_behavioral_sanity', 'invalidated', 'targets exp4_rl_pts_mc_hybrid, invalidated by Steps K.5/K.6 -- legacy, not a current regression'
        'verify_phase_b3_projected_convergence',    'slow-valid',  'production projected-RK4 path -- valid and expected to pass, but a full re-simulation'
    };

    % Completeness guard: every verify_*.m on disk must appear in exactly
    % one of the two lists above. Without this, adding a new oracle (or
    % renaming one) silently drops it from the suite -- which is precisely
    % how verify_step69_plots.m rotted into referencing deleted figures
    % without anyone noticing across four review rounds.
    local_assert_full_coverage(project_root, [fast_tests; deferred_tests(:, 1)]);

    fprintf('=====================================================\n');
    fprintf('  Paper 1608 Verification Suite\n');
    fprintf('=====================================================\n');

    results = struct('name', {}, 'status', {}, 'message', {});
    n_pass = 0; n_fail = 0;

    fprintf('\n--- Algebra-level oracles (%d) ---\n', numel(fast_tests));
    for k = 1:numel(fast_tests)
        [results, n_pass, n_fail] = local_run(fast_tests{k}, results, n_pass, n_fail);
    end

    classes = {'stalling-rl', 'slow-mb', 'slow-valid', 'invalidated'};
    class_desc = { ...
        'genuine Issue K (adaptive solver + RL/critic dynamics)', ...
        'model-based/conventional, no critic -- cost real, cause NOT attributed to Issue K', ...
        'production projected-RK4 path -- valid, just a full re-simulation', ...
        'targets an already-invalidated path -- legacy, not a current regression'};

    if include_integration
        fprintf('\n--- Deferred oracles (%d) -- running anyway; some may not terminate ---\n', ...
            size(deferred_tests, 1));
        for k = 1:size(deferred_tests, 1)
            [results, n_pass, n_fail] = local_run(deferred_tests{k, 1}, results, n_pass, n_fail);
        end
    else
        fprintf('\n--- Deferred oracles (%d), grouped by REASON (not one blanket label) ---\n', ...
            size(deferred_tests, 1));
        for c = 1:numel(classes)
            sel = find(strcmp(deferred_tests(:, 2), classes{c}));
            if isempty(sel), continue; end
            fprintf('\n  [%s] %s\n', classes{c}, class_desc{c});
            for k = sel(:).'
                fprintf('  SKIP   %-42s %s\n', deferred_tests{k, 1}, deferred_tests{k, 3});
                results(end+1) = struct('name', deferred_tests{k, 1}, 'status', 'SKIP', ...
                    'message', sprintf('[%s] %s', deferred_tests{k, 2}, deferred_tests{k, 3})); %#ok<AGROW>
            end
        end
    end

    n_skip = sum(strcmp({results.status}, 'SKIP'));
    fprintf('\n-----------------------------------------------------\n');
    fprintf('Summary: %d passed, %d failed, %d deferred.\n', n_pass, n_fail, n_skip);
    if n_skip > 0
        fprintf(['NOTE: this is a GREEN FAST BLOCK, not a green full suite. The %d deferred\n' ...
                 'oracles are NOT known-passing; see the per-test reasons above.\n'], n_skip);
    end
    fprintf('=====================================================\n');

    % Fail loudly so `matlab -batch` returns a nonzero exit status.
    assert(n_fail == 0, 'run_all_verifications: %d verification oracle(s) FAILED', n_fail);
end

function local_assert_full_coverage(project_root, listed)
    files = dir(fullfile(project_root, 'verify', 'verify_*.m'));
    on_disk = cell(numel(files), 1);
    for k = 1:numel(files)
        on_disk{k} = files(k).name(1:end-2);
    end
    missing = setdiff(on_disk, listed);
    if ~isempty(missing)
        error(['run_all_verifications: %d verify_*.m file(s) exist on disk but are not ' ...
               'listed in either block (silently untested): %s'], ...
               numel(missing), strjoin(missing', ', '));
    end
    stale = setdiff(listed, on_disk);
    if ~isempty(stale)
        error('run_all_verifications: %d listed oracle(s) no longer exist on disk: %s', ...
               numel(stale), strjoin(stale', ', '));
    end
end

function [results, n_pass, n_fail] = local_run(name, results, n_pass, n_fail)
    if exist(name, 'file') ~= 2
        fprintf('FAIL   %s  -- script not found on path\n', name);
        n_fail = n_fail + 1;
        results(end+1) = struct('name', name, 'status', 'FAIL', 'message', 'not found on path');
        return;
    end
    try
        evalc(name);
        fprintf('PASS   %s\n', name);
        n_pass = n_pass + 1;
        results(end+1) = struct('name', name, 'status', 'PASS', 'message', '');
    catch ME
        fprintf('FAIL   %s  -- %s\n', name, ME.message);
        n_fail = n_fail + 1;
        results(end+1) = struct('name', name, 'status', 'FAIL', 'message', ME.message);
    end
end
