clear all; clear functions;
addpath(genpath('paper1608'));
diary('k5_checkpoint_console.txt');

params  = simulation_params();
sat_cfg = saturation_config();
cfg     = nn_config();

[eta_init, nu_init] = initial_conditions();
omega_aw = zeros(6,3);
Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
Wc = zeros(cfg.critic_n_nodes,3);
X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

fprintf('checkpoint: running hot phase [0, 0.15]s, h=1e-6 ...\n');
[t_hot, X_hot, hot_stats] = projected_rk4_integrate(0.15, 1e-6, X0, params, sat_cfg, cfg);
fprintf('checkpoint: hot phase done, %d steps, %.1fs wall\n', hot_stats.nsteps, hot_stats.elapsed);

X_hot_end = X_hot(end,:).';
save('k5_hotphase_checkpoint.mat', 'X_hot_end', 'hot_stats', 'params', 'sat_cfg', 'cfg');
fprintf('checkpoint: saved to k5_hotphase_checkpoint.mat\n');

diary off;
exit;
