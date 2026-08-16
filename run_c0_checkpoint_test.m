clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0_checkpoint_console.txt');

cfg = nn_config();
sat_cfg = saturation_config();
params = simulation_params();
[eta_init, nu_init] = initial_conditions();
omega_aw_mat = zeros(6, 3);
Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
Wc_mat = zeros(cfg.critic_n_nodes, 3);
X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);

opts = struct();
opts.store_stride = 50;
opts.checkpoint_every_sec = 0.05;
opts.checkpoint_path = 'c0_checkpoint_test.mat';

if exist(opts.checkpoint_path, 'file')
    delete(opts.checkpoint_path);
end

[t_hist, X_hist, stats] = projected_rk4_integrate(0.3, 1e-4, X0, params, sat_cfg, cfg, opts);
fprintf('t_hist size=%s\n', mat2str(size(t_hist)));

if exist(opts.checkpoint_path, 'file')
    d = load(opts.checkpoint_path);
    fprintf('CHECKPOINT WRITTEN: t=%.4f, k=%d/%d\n', d.checkpoint.t, d.checkpoint.k, d.checkpoint.nsteps);
else
    fprintf('CHECKPOINT NOT FOUND -- FAIL\n');
end

diary off;
exit;
