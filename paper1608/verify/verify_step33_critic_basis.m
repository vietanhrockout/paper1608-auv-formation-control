function verify_step33_critic_basis()
    % VERIFY_STEP33_CRITIC_BASIS Tests Critic basis dimension (m_c x 1)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'nn'));
    
    cfg = nn_config();
    chi_i = [1; -2; 0.5; -0.1; 0.05; -0.01];
    
    theta_c = critic_basis(chi_i, cfg);
    
    if ~isequal(size(theta_c), [cfg.critic_n_nodes, 1])
        error('STEP 33: FAIL - Critic basis dimension must be m_c x 1');
    end
    if any(theta_c <= 0) || any(theta_c > 1.0)
        error('STEP 33: FAIL - Critic basis activations out of range (0, 1]');
    end
    
    fprintf('STEP 33: PASS\n');
end
