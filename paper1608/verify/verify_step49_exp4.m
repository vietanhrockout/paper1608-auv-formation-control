function verify_step49_exp4()
    % VERIFY_STEP49_EXP4 Tests Experiment 4 execution under RL controller
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp4_rl_pts_mc(0.5);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 49: FAIL - Experiment 4 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 49: FAIL - Experiment 4 state contains NaN or Inf');
    end
    
    fprintf('STEP 49: PASS\n');
end
