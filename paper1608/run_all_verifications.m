% RUN_ALL_VERIFICATIONS.M - Master runner for Targeted Post-Patch Verification Suite

clear; clc;

project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));

fprintf('=====================================================\n');
fprintf('  Running Paper 1608 Targeted Verification Subset\n');
fprintf('=====================================================\n');

% List of verification scripts requested by user (15 tests total)
verifications = {
    'verify_step05_derived_params'
    'verify_step05c_simulation_branch_propagation'
    'verify_step20_reaching_term'
    'verify_step29_nn_config'
    'verify_step32_projection'
    'verify_step32b_unpack_state_transparency'
    'verify_step35_utility'
    'verify_step35b_critic_control_cost_signal'
    'verify_step36_bellman_error'
    'verify_step37_critic_update'
    'verify_step39_actor_update'
    'verify_step40_controller_rl'
    'verify_step43_rhs_3auv_rl'
    'verify_step44_numerical_stability'
    'verify_phase_b1_behavioral_sanity'
};

passed_count = 0;
failed_count = 0;

for k = 1:length(verifications)
    func_name = verifications{k};
    try
        feval(func_name);
        passed_count = passed_count + 1;
    catch ME
        failed_count = failed_count + 1;
        fprintf('  FAILED: %s\n  Error: %s\n', func_name, ME.message);
    end
end

fprintf('-----------------------------------------------------\n');
fprintf('Summary: %d / %d targeted verification tests passed.\n', passed_count, length(verifications));
if failed_count == 0
    fprintf('TARGETED VERIFICATION SUBSET COMPLETED SUCCESSFULLY!\n');
else
    fprintf('SOME VERIFICATION TESTS FAILED. PLEASE AUDIT LOGS.\n');
end
fprintf('=====================================================\n');
