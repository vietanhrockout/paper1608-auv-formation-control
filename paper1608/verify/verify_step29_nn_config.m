function verify_step29_nn_config()
    % VERIFY_STEP29_NN_CONFIG Verifies RBF center dimensions, node count, and weight projection bounds
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    
    cfg = nn_config();
    
    if ~isequal(size(cfg.actor_centers), [2, cfg.actor_n_nodes])
        error('STEP 29: FAIL - Actor centers dimension mismatch');
    end
    if ~isequal(size(cfg.critic_centers), [6, cfg.critic_n_nodes])
        error('STEP 29: FAIL - Critic centers dimension mismatch');
    end
    if cfg.delta_a <= 0 || cfg.delta_c <= 0
        error('STEP 29: FAIL - Projection bounds delta_a and delta_c must be positive');
    end
    
    fprintf('STEP 29: PASS\n');
end
