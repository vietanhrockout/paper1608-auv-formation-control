function [c_ei, Phi_i] = bellman_error(chi_i, vel_err_i, Wc_i, tau_i, params, cfg)
    % BELLMAN_ERROR Computes Bellman residual error c_{ei} (Eq. 17)
    % Phi_i = -\frac{1}{\lambda} \theta_c(\chi_i) + \nabla \theta_c(\chi_i) \upsilon_i
    % c_{ei} = r_i(t) + \hat{w}_{ci}^T \Phi_i
    
    if nargin < 5 || isempty(params)
        params = paper_params();
    end
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end
    
    r_i = strategic_utility(chi_i, tau_i);
    
    th_c = critic_basis(chi_i, cfg);
    
    % Derivative of RBF basis \theta_c w.r.t tracking error \chi_i
    % \theta_k = exp( - ||\chi - c_k||^2 / l_c^2 )
    % \frac{\partial \theta_k}{\partial \chi} = -\frac{2(\chi - c_k)}{l_c^2} \theta_k
    n_nodes = cfg.critic_n_nodes;
    dth_dchi = zeros(n_nodes, 6);
    width_sq = cfg.critic_width^2;
    
    for k = 1:n_nodes
        diff = chi_i - cfg.critic_centers(:, k);
        dth_dchi(k, :) = -2 * (diff') / width_sq * th_c(k);
    end
    
    th_dot = dth_dchi * vel_err_i; % 15x1
    
    lambda = params.lambda;
    Phi_i = -(1 / lambda) * th_c + th_dot; % 15x1
    
    c_ei = r_i + Wc_i' * Phi_i; % scalar Bellman residual
end
