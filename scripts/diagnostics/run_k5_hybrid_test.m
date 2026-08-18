clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k5_hybrid_test_console.txt'));

res = exp4_rl_pts_mc_hybrid(2.0, 0.15, 1e-6);

cfg = nn_config();
[eta_m, nu_m, omega_m, Wa_c, Wc_m] = unpack_states(res.X(end,:).', cfg);

fprintf('\n============================================================\n');
fprintf(' K.5 HYBRID VALIDATION SUMMARY (t_final=2.0s)\n');
fprintf('============================================================\n');
fprintf('total output points = %d\n', numel(res.t));
fprintf('final t = %.6f\n', res.t(end));
fprintf('any NaN/Inf in X: %d\n', any(isnan(res.X(:))) || any(isinf(res.X(:))));
for i = 1:3
    fprintf('AUV%d: ||Wc||=%.6f  ||Wa||_F=%.6f  eta=[%.4f %.4f %.4f]\n', ...
        i-1, norm(Wc_m(:,i)), norm(Wa_c{i},'fro'), eta_m(1,i), eta_m(2,i), eta_m(3,i));
end

save(fullfile(paths.diagnostics, 'k5_hybrid_test_result.mat'), 'res');

diary off;
exit;
