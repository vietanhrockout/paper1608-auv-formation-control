function verify_step41_sat_antiwindup_loop()
    % VERIFY_STEP41_SAT_ANTIWINDUP_LOOP Tests complete saturation and anti-windup loop consistency
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    params = paper_params();
    params = derived_params(params);
    sat_cfg = saturation_config();
    cfg = nn_config();
    
    eta = [5; 5; -10; 0.2; -0.2; 0.3];
    eta_dot = [1.0; -0.5; 0.3; 0.05; -0.05; 0.02];
    t = 0.5;
    omega_aw_i = zeros(6, 1);
    Wa_i = zeros(cfg.actor_n_nodes, 6);
    
    % 1. Compute control command
    [tau_cmd, ~] = controller_rl(eta, eta_dot, t, 1, omega_aw_i, Wa_i, params, cfg);
    
    % 2. Apply saturation
    [tau_act, delta_tau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
    
    % 3. Compute anti-windup state derivative
    [chi, vel_err] = formation_error(eta, eta_dot, t, 1);
    s = sliding_surface(chi, vel_err, params);
    omega_dot = antiwindup_rhs(omega_aw_i, s, delta_tau, params);
    
    if any(isnan(tau_act)) || any(isnan(delta_tau)) || any(isnan(omega_dot))
        error('STEP 41: FAIL - Saturation and anti-windup loop produced NaN');
    end
    if norm(tau_act - (tau_cmd + delta_tau)) > 1e-12
        error('STEP 41: FAIL - Saturation identity violated in loop');
    end
    
    fprintf('STEP 41: PASS\n');
end
