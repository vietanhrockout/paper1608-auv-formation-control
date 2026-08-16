function verify_step31_actor_output()
    % VERIFY_STEP31_ACTOR_OUTPUT Tests Actor NN output dimensions (6x1) and smoothness
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'nn'));
    
    cfg = nn_config();
    chi = [1; 2; -3; 0.1; -0.2; 0.3];
    vel_err = [0.5; -0.1; 0.2; -0.01; 0.02; -0.03];
    Wa_i = randn(cfg.actor_n_nodes, 6);
    
    f_rl = actor_output(chi, vel_err, Wa_i, cfg);
    
    if ~isequal(size(f_rl), [6, 1])
        error('STEP 31: FAIL - Actor output vector dimension must be 6x1');
    end
    if any(isnan(f_rl)) || any(isinf(f_rl))
        error('STEP 31: FAIL - Actor output contains NaN or Inf');
    end
    
    fprintf('STEP 31: PASS\n');
end
