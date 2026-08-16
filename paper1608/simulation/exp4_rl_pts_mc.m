function res = exp4_rl_pts_mc(t_final, params, sat_cfg, cfg)
    % EXP4_RL_PTS_MC Experiment 4: Proposed Actor-Critic RL Predefined-Time SMC Controller (Paper 1608 Main)
    
    if nargin < 1 || isempty(t_final)
        t_final = 20.0;
    end
    if nargin < 2 || isempty(params)
        params = simulation_params();
    end
    if nargin < 3 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    if nargin < 4 || isempty(cfg)
        cfg = nn_config();
    end
    
    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);
    
    tspan = linspace(0, t_final, 301);
    options = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 5e-2);
    
    [t_out, X_out] = ode45(@(t, X) rhs_3auv_rl(t, X, params, sat_cfg, cfg), tspan, X0, options);
    
    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC';
end
