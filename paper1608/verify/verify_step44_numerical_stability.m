function verify_step44_numerical_stability()
    % VERIFY_STEP44_NUMERICAL_STABILITY Runs closed-loop 549-state ODE integration for 0.5s and checks bounds
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    params = simulation_params();
    sat_cfg = saturation_config();
    cfg = nn_config();
    
    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);
    
    tspan = linspace(0, 0.5, 101);
    options = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 1e-2);
    
    [t_out, X_out] = ode45(@(t, X) rhs_3auv_rl(t, X, params, sat_cfg, cfg), tspan, X0, options);
    
    if any(isnan(X_out(:))) || any(isinf(X_out(:)))
        error('STEP 44: FAIL - Closed-loop simulation state contains NaN or Inf');
    end
    
    % Check parameter bounds projection compliance at final state
    X_final = X_out(end, :)';
    [~, ~, ~, Wa_final, Wc_final] = unpack_states(X_final, cfg);
    
    for i = 1:3
        if norm(Wc_final(:, i)) > cfg.delta_c + 1e-5
            error('STEP 44: FAIL - Critic weight bound delta_c exceeded');
        end
        for j = 1:6
            if norm(Wa_final{i}(:, j)) > cfg.delta_a + 1e-5
                error('STEP 44: FAIL - Actor weight bound delta_a exceeded');
            end
        end
    end
    
    fprintf('STEP 44: PASS (Numerical ODE Step Stability verified on simulation_params branch)\n');
end
