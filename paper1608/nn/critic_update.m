function dWc_i = critic_update(chi_i, vel_err_i, Wc_i, tau_i, params, cfg)
    % CRITIC_UPDATE Critic weight update derivative \dot{\hat{w}}_{ci} (Eq. 19, 20)
    % \dot{\hat{w}}_{ci} = Proj( -\lambda_c c_{ei} \Phi_i )
    
    if nargin < 5 || isempty(params)
        params = paper_params();
    end
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end
    
    [c_ei, Phi_i] = bellman_error(chi_i, vel_err_i, Wc_i, tau_i, params, cfg);
    
    % Raw gradient descent update law (Eq. 19)
    desired_update = -params.lambda_c * c_ei * Phi_i;
    
    % Apply parameter projection operator (Eq. 20)
    delta_c = cfg.delta_c; % 100
    dWc_i = projection_operator(Wc_i, desired_update, delta_c);
end
