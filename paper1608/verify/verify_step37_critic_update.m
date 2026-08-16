function verify_step37_critic_update()
    % VERIFY_STEP37_CRITIC_UPDATE Verifies Critic update law gradient descent (Paper Eq. 19, 20)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    params = paper_params();
    cfg = nn_config();
    chi_i = [1; -1; 0.5; -0.1; 0.05; -0.01];
    vel_err_i = [0.1; -0.05; 0.02; -0.01; 0.005; -0.002];
    Wc_i = zeros(15, 1);
    tau_i = [10; -10; 5; -1; 0.5; -0.2];
    
    [c_ei, Phi_i] = bellman_error(chi_i, vel_err_i, Wc_i, tau_i, params, cfg);
    dWc_i = critic_update(chi_i, vel_err_i, Wc_i, tau_i, params, cfg);
    
    desired_update = -params.lambda_c * c_ei * Phi_i;
    if norm(dWc_i - desired_update) > 1e-12
        error('STEP 37: FAIL - Critic update sign or magnitude does not match Paper Eq. (19)');
    end
    
    fprintf('STEP 37: PASS\n');
end
