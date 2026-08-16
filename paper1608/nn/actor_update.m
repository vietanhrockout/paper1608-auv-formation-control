function dWa_i = actor_update(chi_i, vel_err_i, Wa_i, Wc_i, params, cfg)
    % ACTOR_UPDATE Actor weight update derivative \dot{\hat{W}}_{ai} (Eq. 37, 38)
    % \dot{\hat{w}}_{aij} = Proj( -\lambda_a \tanh( \hat{w}_{aij}^T \theta_{aij} + c_{0a} \hat{C}_i ) \theta_{aij} )
    
    if nargin < 5 || isempty(params)
        params = paper_params();
    end
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end
    
    % Compute scalar estimated Critic cost C_hat_i
    C_hat_i = critic_output(chi_i, Wc_i, cfg);
    
    dWa_i = zeros(cfg.actor_n_nodes, 6);
    delta_a = cfg.actor_weight_bound; % 50
    
    for j = 1:6
        % Correct indexing: vel_err_i(j) is the velocity error for DOF j
        th_aj = actor_basis(chi_i(j), vel_err_i(j), cfg);
        
        f_rl_j = Wa_i(:, j)' * th_aj; % scalar estimated drift for DOF j
        
        arg_tanh = f_rl_j + params.c0a * C_hat_i;
        desired_update = -params.lambda_a * tanh(arg_tanh) * th_aj;
        
        dWa_i(:, j) = projection_operator(Wa_i(:, j), desired_update, delta_a);
    end
end
