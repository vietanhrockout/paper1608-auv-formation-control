function verify_step30_actor_basis()
    % VERIFY_STEP30_ACTOR_BASIS Tests Actor basis activations dimension (m_a x 1)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'nn'));
    
    cfg = nn_config();
    chi_j = 1.5;
    vel_err_j = -0.5;
    
    theta_a = actor_basis(chi_j, vel_err_j, cfg);
    
    if ~isequal(size(theta_a), [cfg.actor_n_nodes, 1])
        error('STEP 30: FAIL - Actor basis vector dimension must be m_a x 1');
    end
    if any(theta_a <= 0) || any(theta_a > 1.0)
        error('STEP 30: FAIL - Actor basis activations out of range (0, 1]');
    end
    
    fprintf('STEP 30: PASS\n');
end
