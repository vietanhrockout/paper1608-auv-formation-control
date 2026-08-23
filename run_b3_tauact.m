% Phase B.3-equivalent 15s convergence check under the NEW production default
% params.critic_reward_tau_mode = 'tau_act_saturated' (Issue M resolved by
% supervisor determination). Directly comparable to the earlier B.3 run made
% under 'tau_cmd_raw', which gave E_chi: 16.0 -> 0.0037 over the same horizon
% at the same step size.
clear all; clear functions;
addpath(genpath('paper1608'));
p = simulation_params();
fprintf('critic_reward_tau_mode = %s\n', p.critic_reward_tau_mode);
fprintf('inverse_lambda_mode    = %s\n', p.inverse_lambda_mode);
res = verify_phase_b3_projected_convergence(15.0, 1e-4);
save('phase_c_results/b3_tauact_result_t15.mat', 'res', '-v7.3');
exit;
