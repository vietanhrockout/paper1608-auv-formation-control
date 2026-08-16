function dX = rhs_3auv_rl(t, X, params, sat_cfg, cfg)
    % RHS_3AUV_RL Master 549-state closed-loop ODE RHS for 3 AUVs under RL PT-SMC
    % Completely Model-Free Compliant (Does not use f_true for training)
    
    if nargin < 3 || isempty(params)
        params = simulation_params();
    end
    if nargin < 4 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    if nargin < 5 || isempty(cfg)
        cfg = nn_config();
    end
    
    [eta_mat, nu_mat, omega_aw_mat, Wa_cell, Wc_mat] = unpack_states(X, cfg);
    
    d_eta_mat = zeros(6, 3);
    d_nu_mat  = zeros(6, 3);
    d_omega_mat = zeros(6, 3);
    d_Wa_cell = cell(1, 3);
    d_Wc_mat  = zeros(cfg.critic_n_nodes, 3);
    
    for i = 1:3
        eta = eta_mat(:, i);
        nu  = nu_mat(:, i);
        omega_aw = omega_aw_mat(:, i);
        Wa_i = Wa_cell{i};
        Wc_i = Wc_mat(:, i);
        
        J = jacobian_J(eta);
        eta_dot = J * nu;
        
        [chi, vel_err] = formation_error(eta, eta_dot, t, i);
        s = sliding_surface(chi, vel_err, params);
        
        % Control signal calculation (Eq. 31)
        tau_cmd = controller_rl(eta, eta_dot, t, i, omega_aw, Wa_i, params, cfg);
        [tau_act, delta_tau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
        tau_d = ocean_disturbance(t, i);
        
        % AUV plant dynamics (True 6-DOF Hydrodynamic Plant)
        [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_act, tau_d);
        
        % Adaptive anti-windup ODE (Eq. 30)
        omega_dot = antiwindup_rhs(omega_aw, s, delta_tau, params);
        
        % Model-Free Actor learning update (Eq. 37, 38)
        dWa_i = actor_update(chi, vel_err, Wa_i, Wc_i, params, cfg);
        
        % Critic learning update (Eq. 19, 20). Eq. 16 reward torque argument
        % mode is controlled by params.critic_reward_tau_mode (Issue M,
        % documented in config/paper_params.m and diagnosed in
        % verify/diagnose_stepM1_critic_reward_saturation_coupling.m).
        if isfield(params, 'critic_reward_tau_mode') && ...
                strcmp(params.critic_reward_tau_mode, 'tau_act_saturated')
            tau_reward = tau_act;
        else
            tau_reward = tau_cmd; % 'tau_cmd_raw': literal Eq. 16 reading (default)
        end
        dWc_i = critic_update(chi, vel_err, Wc_i, tau_reward, params, cfg);
        
        d_eta_mat(:, i)   = eta_dot_plant;
        d_nu_mat(:, i)    = nu_dot_plant;
        d_omega_mat(:, i) = omega_dot;
        d_Wa_cell{i}     = dWa_i;
        d_Wc_mat(:, i)    = dWc_i;
    end
    
    dX = pack_states(d_eta_mat, d_nu_mat, d_omega_mat, d_Wa_cell, d_Wc_mat, cfg);
end
