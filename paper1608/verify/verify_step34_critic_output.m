function verify_step34_critic_output()
    % VERIFY_STEP34_CRITIC_OUTPUT Tests Critic value function scalar output
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'nn'));
    
    cfg = nn_config();
    chi_i = [1; -2; 0.5; -0.1; 0.05; -0.01];
    Wc_i = randn(cfg.critic_n_nodes, 1);
    
    V_hat = critic_output(chi_i, Wc_i, cfg);
    
    if ~isscalar(V_hat) || isnan(V_hat) || isinf(V_hat)
        error('STEP 34: FAIL - Critic output must be a valid real scalar');
    end
    
    fprintf('STEP 34: PASS\n');
end
