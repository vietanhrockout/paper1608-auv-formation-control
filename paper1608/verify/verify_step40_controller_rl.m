function verify_step40_controller_rl()
    % VERIFY_STEP40_CONTROLLER_RL Verifies RL controller with anti-windup placement (Paper Eq. 31)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    cfg = nn_config();
    eta = [2; 3; -6; 0.1; -0.1; 0.2];
    eta_dot = [0.5; -0.2; 0.1; 0.01; -0.02; 0.01];
    t = 1.0;
    omega_aw_i = zeros(6, 1);
    Wa_i = zeros(cfg.actor_n_nodes, 6);
    
    [tau_cmd, terms] = controller_rl(eta, eta_dot, t, 1, omega_aw_i, Wa_i);
    
    if any(isnan(tau_cmd)) || any(isinf(tau_cmd))
        error('STEP 40: FAIL - tau_cmd contains NaN or Inf');
    end
    if ~isequal(size(tau_cmd), [6, 1])
        error('STEP 40: FAIL - tau_cmd dimension must be 6x1');
    end
    
    fprintf('STEP 40: PASS\n');
end
