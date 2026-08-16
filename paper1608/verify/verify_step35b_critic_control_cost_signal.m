function verify_step35b_critic_control_cost_signal()
    % VERIFY_STEP35B_CRITIC_CONTROL_COST_SIGNAL Audits r_i(t) cost signal (Paper Eq. 16)
    % Compares r_cmd(t) using tau_cmd vs r_act(t) using tau_act under saturation.
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    chi_i = [1; -1; 0.5; -0.1; 0.05; -0.01];
    tau_cmd = [300; -300; 200; 80; -80; 60];
    
    sat_cfg = saturation_config();
    [tau_act, ~] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
    
    % Compute costs
    r_cmd = strategic_utility(chi_i, tau_cmd);
    r_act = strategic_utility(chi_i, tau_act);
    
    % 1. Exact numeric oracle check
    expected_r_cmd = 25.9026;
    expected_r_act = 9.2826;
    
    if abs(r_cmd - expected_r_cmd) > 1e-4
        error('STEP 35b: FAIL - Unexpected r_cmd value (got %.4f, expected %.4f)', r_cmd, expected_r_cmd);
    end
    if abs(r_act - expected_r_act) > 1e-4
        error('STEP 35b: FAIL - Unexpected r_act value (got %.4f, expected %.4f)', r_act, expected_r_act);
    end
    
    % 2. Under saturation, r_cmd must be strictly greater than r_act
    if r_cmd <= r_act
        error('STEP 35b: FAIL - Control command cost r_cmd must be strictly greater than saturated cost r_act');
    end
    
    fprintf('STEP 35b: PASS (r_cmd=%.4f, r_act=%.4f, tau_cmd cost path verified)\n', r_cmd, r_act);
end
