function verify_step05c_simulation_branch_propagation()
    % VERIFY_STEP05C_SIMULATION_BRANCH_PROPAGATION Verifies behavioral branch propagation
    % Hardened with nontrivial probe state (s != 0) ensuring nonzero branch separation
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    cfg = nn_config();
    p_sim = simulation_params();
    p_pdf = derived_params(paper_params());
    
    % Test 1: Direct Controller Branch Separation Test on nontrivial error state (s != 0)
    eta_probe = [2; 3; -6; 0.1; -0.1; 0.2];
    eta_dot_probe = [0.5; -0.2; 0.1; 0.01; -0.02; 0.01];
    
    i_probe = 1;
    omega_probe = zeros(6, 1);
    Wa_probe = zeros(cfg.actor_n_nodes, 6);
    
    % Call with 6 arguments (omitting 7th params argument to test default loading)
    tau_default = controller_rl(eta_probe, eta_dot_probe, 1.0, i_probe, omega_probe, Wa_probe);
    
    % Call explicitly with 7th params argument for simulation vs paper_literal
    tau_sim     = controller_rl(eta_probe, eta_dot_probe, 1.0, i_probe, omega_probe, Wa_probe, p_sim, cfg);
    tau_literal = controller_rl(eta_probe, eta_dot_probe, 1.0, i_probe, omega_probe, Wa_probe, p_pdf, cfg);
    
    % Assert default controller matches simulation_params() branch exactly
    err_ctrl_default = norm(tau_default - tau_sim, inf);
    if err_ctrl_default > 1e-10
        error('STEP 05c: FAIL - Default controller output does not match simulation_params branch');
    end
    
    % Assert probe state excites reaching gains and produces clear branch separation
    sep_ctrl = norm(tau_sim - tau_literal, inf);
    if sep_ctrl < 1e-3
        error('STEP 05c: FAIL - Probe state failed to produce controller branch separation (sep = %.6f)', sep_ctrl);
    end
    
    % Test 2: Master 549-State RHS Branch Separation Test
    [eta_init, nu_init] = initial_conditions();
    
    % Shift initial positions so chi != 0 and s != 0
    eta_probe_mat = eta_init + [1 2 3; 1 2 3; 1 2 3; 0.1 0.1 0.1; 0.1 0.1 0.1; 0.1 0.1 0.1];
    Xprobe = pack_states(eta_probe_mat, nu_init, zeros(6, 3), {zeros(25, 6), zeros(25, 6), zeros(25, 6)}, zeros(15, 3), cfg);
    
    dX_default = rhs_3auv_rl(1.0, Xprobe); % No params passed
    dX_sim     = rhs_3auv_rl(1.0, Xprobe, p_sim);
    dX_literal = rhs_3auv_rl(1.0, Xprobe, p_pdf);
    
    err_rhs_default = norm(dX_default - dX_sim, inf);
    if err_rhs_default > 1e-10
        error('STEP 05c: FAIL - Default RHS evaluation does not match simulation_params branch');
    end
    
    sep_rhs = norm(dX_sim - dX_literal, inf);
    if sep_rhs < 1e-3
        error('STEP 05c: FAIL - Probe state failed to produce RHS branch separation (sep = %.6f)', sep_rhs);
    end
    
    fprintf('STEP 05c: PASS (Hardened Behavioral Oracle: Default == eq29_consistent, eq29_consistent != paper_literal ctrl_sep=%.4f, rhs_sep=%.4f)\n', sep_ctrl, sep_rhs);
end
