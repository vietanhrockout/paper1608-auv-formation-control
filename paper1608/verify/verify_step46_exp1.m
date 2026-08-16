function verify_step46_exp1()
    % VERIFY_STEP46_EXP1 Tests Experiment 1 execution under ocean current disturbances
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp1_disturbed_mb(1.0);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 46: FAIL - Experiment 1 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 46: FAIL - Experiment 1 state contains NaN or Inf');
    end
    
    fprintf('STEP 46: PASS\n');
end
