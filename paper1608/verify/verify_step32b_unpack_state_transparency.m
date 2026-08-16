function verify_step32b_unpack_state_transparency()
    % VERIFY_STEP32B_UNPACK_STATE_TRANSPARENCY Verifies state serialization transparency
    % Proves unpack_states does not apply hidden clipping to out-of-bound ODE weights (Issue J Oracle)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    cfg = nn_config();
    
    % Construct artificial state components with explicit out-of-bound weights
    eta_test = [1; 2; -3; 0.1; -0.1; 0.2] * ones(1, 3);
    nu_test  = [0.1; -0.1; 0.2; 0.01; -0.01; 0.02] * ones(1, 3);
    omega_aw_test = [0.5; -0.5; 0.2; -0.1; 0.1; -0.05] * ones(1, 3);
    
    % Out of bound weights: ||Wc|| = 120 > delta_c (100), ||Wa|| = 60 > delta_a (50)
    Wc_out_of_bounds = ones(cfg.critic_n_nodes, 1) * (120.0 / sqrt(cfg.critic_n_nodes));
    Wa_out_of_bounds = ones(cfg.actor_n_nodes, 6) * (60.0 / sqrt(cfg.actor_n_nodes));
    
    Wa_test_cell = {Wa_out_of_bounds, Wa_out_of_bounds, Wa_out_of_bounds};
    Wc_test_mat  = [Wc_out_of_bounds, Wc_out_of_bounds, Wc_out_of_bounds];
    
    % Assert initial constructed norms exceed standard bounds
    assert(norm(Wc_out_of_bounds) > cfg.delta_c + 10.0, 'Test setup error: Wc norm not out of bounds');
    assert(norm(Wa_out_of_bounds(:, 1)) > cfg.delta_a + 5.0, 'Test setup error: Wa norm not out of bounds');
    
    % Pack states into 549x1 vector
    X_packed = pack_states(eta_test, nu_test, omega_aw_test, Wa_test_cell, Wc_test_mat, cfg);
    
    % Unpack states through unpack_states
    [~, ~, ~, Wa_unpacked, Wc_unpacked] = unpack_states(X_packed, cfg);
    
    % Assert exact state transparency: unpack_states MUST NOT mutate raw ODE states
    err_c = norm(Wc_unpacked - Wc_test_mat, Inf);
    err_a1 = norm(Wa_unpacked{1} - Wa_test_cell{1}, Inf);
    err_a2 = norm(Wa_unpacked{2} - Wa_test_cell{2}, Inf);
    err_a3 = norm(Wa_unpacked{3} - Wa_test_cell{3}, Inf);
    
    if err_c > 1e-12 || err_a1 > 1e-12 || err_a2 > 1e-12 || err_a3 > 1e-12
        error('STEP 32b: FAIL - unpack_states mutated ODE state vector (err_c=%.2e, err_a=%.2e)', err_c, err_a1);
    end
    
    fprintf('STEP 32b: PASS (State transparency verified: unpack_states does not clip out-of-bound weights err_c=%.2e, err_a=%.2e)\n', err_c, err_a1);
end
