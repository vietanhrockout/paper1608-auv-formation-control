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
        'verify_step69_plots'           % surface-only check, does not re-render (see its header)
        'verify_step72_tuning'
    };

    % Integration-level oracles -- gated on Issue K (see header).
    integration_tests = {
        'verify_step23_single_auv_mb'
        'verify_step24_3auv_mb'
        'verify_step41_sat_antiwindup_loop'
        'verify_step44_numerical_stability'
        'verify_step45_exp0'
        'verify_step46_exp1'
        'verify_step47_exp2'
        'verify_step48_exp3'
        'verify_step49_exp4'
        'verify_step50_exp5'
        'verify_step51_exp_runner'
        'verify_step52_performance_criteria'
        'verify_step55_pt_validation'
        'verify_phase_b1_behavioral_sanity'
        'verify_phase_b2_hybrid_behavioral_sanity'
        'verify_phase_b3_projected_convergence'
    };

    % Completeness guard: every verify_*.m on disk must appear in exactly
    % one of the two lists above. Without this, adding a new oracle (or
    % renaming one) silently drops it from the suite -- which is precisely
    % how verify_step69_plots.m rotted into referencing deleted figures
    % without anyone noticing across four review rounds.
    local_assert_full_coverage(project_root, [fast_tests; integration_tests]);

    fprintf('=====================================================\n');
    fprintf('  Paper 1608 Verification Suite\n');
    fprintf('=====================================================\n');

    results = struct('name', {}, 'status', {}, 'message', {});
    n_pass = 0; n_fail = 0;

    fprintf('\n--- Algebra-level oracles (%d) ---\n', numel(fast_tests));
    for k = 1:numel(fast_tests)
        [results, n_pass, n_fail] = local_run(fast_tests{k}, results, n_pass, n_fail);
    end

    if include_integration
        fprintf('\n--- Integration-level oracles (%d) -- Issue K: may not terminate ---\n', ...
            numel(integration_tests));
        for k = 1:numel(integration_tests)
            [results, n_pass, n_fail] = local_run(integration_tests{k}, results, n_pass, n_fail);
        end
    else
        fprintf('\n--- Integration-level oracles (%d): SKIPPED (Issue K) ---\n', numel(integration_tests));
        for k = 1:numel(integration_tests)
            fprintf('SKIP   %s\n', integration_tests{k});
            results(end+1) = struct('name', integration_tests{k}, 'status', 'SKIP', ...
                'message', 'Issue K: ode45-based integration path does not terminate here'); %#ok<AGROW>
        end
    end

    n_skip = sum(strcmp({results.status}, 'SKIP'));
    fprintf('\n-----------------------------------------------------\n');
    fprintf('Summary: %d passed, %d failed, %d skipped.\n', n_pass, n_fail, n_skip);
    if n_skip > 0
        fprintf('Skipped oracles are Issue-K-gated and are NOT known-passing.\n');
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
