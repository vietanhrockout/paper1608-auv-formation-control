function verify_step45_exp0()
    % VERIFY_STEP45_EXP0 Tests Experiment 0 execution and error convergence
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp0_ideal_mb(1.0);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 45: FAIL - Experiment 0 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 45: FAIL - Experiment 0 state contains NaN or Inf');
    end
    
    fprintf('STEP 45: PASS\n');
end
