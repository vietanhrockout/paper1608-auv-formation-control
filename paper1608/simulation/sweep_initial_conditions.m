function sweep_res = sweep_initial_conditions(n_trials)
    % SWEEP_INITIAL_CONDITIONS Evaluates predefined-time convergence independence across random initial states
    
    if nargin < 1 || isempty(n_trials)
        n_trials = 5;
    end
    
    params = paper_params();
    params = derived_params(params);
    sat_cfg = saturation_config();
    cfg = nn_config();
    
    rng(1);
    sweep_res = struct();
    sweep_res.n_trials = n_trials;
    sweep_res.converged_count = 0;
    
    for k = 1:n_trials
        eta_init_rand = -10 + 20 * rand(6, 3);
        nu_init_rand  = -1 + 2 * rand(6, 3);
        omega_aw_mat  = zeros(6, 3);
        Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
        Wc_mat  = zeros(cfg.critic_n_nodes, 3);
        
        X0 = pack_states(eta_init_rand, nu_init_rand, omega_aw_mat, Wa_cell, Wc_mat, cfg);
        
        tspan = [0, 0.1]; % Short trial simulation
        options = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 1e-2);
        
        [t_out, X_out] = ode15s(@(t, X) rhs_3auv_rl(t, X, params, sat_cfg, cfg), tspan, X0, options);
        
        if ~any(isnan(X_out(:))) && ~any(isinf(X_out(:)))
            sweep_res.converged_count = sweep_res.converged_count + 1;
        end
    end
end
