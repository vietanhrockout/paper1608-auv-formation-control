function verify_step42_state_packing()
    % VERIFY_STEP42_STATE_PACKING Tests state packing and unpacking round-trip identity
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'simulation'));
    
    cfg = nn_config();
    
    eta_mat = randn(6, 3);
    nu_mat = randn(6, 3);
    omega_aw_mat = randn(6, 3);
    Wa_cell = {randn(cfg.actor_n_nodes, 6), randn(cfg.actor_n_nodes, 6), randn(cfg.actor_n_nodes, 6)};
    Wc_mat = randn(cfg.critic_n_nodes, 3);
    
    X = pack_states(eta_mat, nu_mat, omega_aw_mat, Wa_cell, Wc_mat, cfg);
    
    if length(X) ~= 549
        error('STEP 42: FAIL - State vector length must be exactly 549');
    end
    
    [eta_out, nu_out, omega_out, Wa_out, Wc_out] = unpack_states(X, cfg);
    
    if norm(eta_mat - eta_out) > 1e-12 || norm(nu_mat - nu_out) > 1e-12 || norm(omega_aw_mat - omega_out) > 1e-12
        error('STEP 42: FAIL - Kinematic/antiwindup state unpack mismatch');
    end
    if norm(Wc_mat - Wc_out) > 1e-12 || norm(Wa_cell{1} - Wa_out{1}) > 1e-12
        error('STEP 42: FAIL - Weight matrix unpack mismatch');
    end
    
    fprintf('STEP 42: PASS\n');
end
