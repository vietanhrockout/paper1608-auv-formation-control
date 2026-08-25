% Phase B.3-equivalent 15s convergence check under the production default
% params.critic_reward_tau_mode = 'tau_act_saturated' (Issue M resolved by
% the supervisor's determination that Eq. 16's tau_i is the actuator-saturated
% input). Directly comparable to scripts/validation/run_b3.m, which produced
% the earlier 'tau_cmd_raw' result E_chi: 16.0 -> 0.0037 at the same horizon
% and step size. See docs/HANDOFF.md, "Issue M RESOLVED".
clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();

p = simulation_params();
% R16 [P2]: assert the mode rather than merely printing a mutable default,
% so this launcher cannot silently produce a tau_cmd_raw dataset.
assert(strcmp(p.critic_reward_tau_mode, 'tau_act_saturated'), ...
    'run_b3_tauact: expected tau_act_saturated, got %s', p.critic_reward_tau_mode);
fprintf('critic_reward_tau_mode = %s\n', p.critic_reward_tau_mode);
fprintf('inverse_lambda_mode    = %s\n', p.inverse_lambda_mode);

res = verify_phase_b3_projected_convergence(15.0, 1e-4);
save(fullfile(paths.validation, 'b3_tauact_result_t15.mat'), 'res', '-v7.3');

exit;
