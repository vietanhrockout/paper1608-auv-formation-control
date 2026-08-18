clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'c0_regression_console.txt'));

fprintf('=== C.0 regression: exp4_rl_pts_mc_projected with new memory-safe integrator ===\n');
res = exp4_rl_pts_mc_projected(0.5, 1e-4);
fprintf('res.t size: %s, res.X size: %s\n', mat2str(size(res.t)), mat2str(size(res.X)));
fprintf('t(1)=%.6f t(end)=%.6f\n', res.t(1), res.t(end));

cfg = nn_config();
[eta_m, nu_m, ~, ~, Wc_m] = unpack_states(res.X(end,:).', cfg);
J0 = jacobian_J(eta_m(:,1));
eta0_dot = J0 * nu_m(:,1);
[chi0, ~] = formation_error(eta_m(:,1), eta0_dot, res.t(end), 1);
fprintf('AUV0 chi at t=%.4f: [%s]\n', res.t(end), num2str(chi0', '%10.6f'));
fprintf('max ||Wc|| = %.6f\n', max(vecnorm(Wc_m)));

exist_checkpoint = exist(fullfile(paths.phase_c_work, 'projected_rk4_checkpoint.mat'), 'file');
fprintf('checkpoint file written: %d\n', exist_checkpoint);

fprintf('=== END C.0 regression ===\n');
diary off;
exit;
