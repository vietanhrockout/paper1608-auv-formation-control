clear all; clear functions;
addpath(genpath('paper1608'));
diary('phase_b2_console.txt');

res = exp4_rl_pts_mc_projected(15.0, 1e-4);
save('phase_b2_result.mat', 'res');

cfg = nn_config();
sat_cfg = saturation_config();
params = res.params;

N_steps = length(res.t);
E_chi = zeros(N_steps,1);
E_s = zeros(N_steps,1);
max_tau_act = 0;

for k = 1:N_steps
    Xk = res.X(k,:).';
    [eta_m, nu_m, omega_m, Wa_l, Wc_m] = unpack_states(Xk, cfg);
    e_chi_k = zeros(3,1);
    e_s_k = zeros(3,1);
    for i = 1:3
        eta = eta_m(:,i); nu = nu_m(:,i);
        J = jacobian_J(eta); eta_dot = J*nu;
        [chi, vel_err] = formation_error(eta, eta_dot, res.t(k), i);
        s = sliding_surface(chi, vel_err, params);
        e_chi_k(i) = max(abs(chi));
        e_s_k(i) = max(abs(s));
        if norm(Wc_m(:,i)) > cfg.delta_c + 1e-4
            fprintf('WARNING: AUV%d Wc exceeded delta_c at t=%.4f\n', i-1, res.t(k));
        end
        tau_cmd = controller_rl(eta, eta_dot, res.t(k), i, omega_m(:,i), Wa_l{i}, params, cfg);
        [tau_act, ~] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
        max_tau_act = max(max_tau_act, max(abs(tau_act(1:3))));
    end
    E_chi(k) = max(e_chi_k);
    E_s(k) = max(e_s_k);
end

fprintf('\n=== PHASE B.2 SUMMARY ===\n');
fprintf('t final = %.4f\n', res.t(end));
fprintf('any NaN/Inf: %d\n', any(isnan(res.X(:))) || any(isinf(res.X(:))));
fprintf('max tau_act force: %.4f N (limit 150)\n', max_tau_act);
sample_t = [0, 0.15, 1, 3, 5, 10, 15];
for st = sample_t
    [~,idx] = min(abs(res.t - st));
    fprintf('t=%.2f  E_chi=%.4f  E_s=%.4f\n', res.t(idx), E_chi(idx), E_s(idx));
end
fprintf('=== PHASE B.2 DONE ===\n');

diary off;
exit;
