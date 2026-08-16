function verify_step43_rhs_3auv_rl()
    % VERIFY_STEP43_RHS_3AUV_RL Verifies master 549-state model-free closed loop ODE RHS
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    cfg = nn_config();
    [eta_init, nu_init] = initial_conditions();
    omega_aw_mat = zeros(6, 3);
    Wa_cell = {zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6), zeros(cfg.actor_n_nodes, 6)};
    Wc_mat = zeros(cfg.critic_n_nodes, 3);
    
    X0 = pack_states(eta_init, nu_init, omega_aw_mat, Wa_cell, Wc_mat, cfg);
    
    dX = rhs_3auv_rl(0.0, X0);
    
    if any(isnan(dX)) || any(isinf(dX))
        error('STEP 43: FAIL - Master ODE RHS dX contains NaN or Inf');
    end
    if length(dX) ~= 549
        error('STEP 43: FAIL - Master ODE RHS dX length must be 549');
    end
    
    fprintf('STEP 43: PASS\n');
end
