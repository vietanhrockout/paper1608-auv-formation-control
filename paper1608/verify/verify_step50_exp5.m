function verify_step50_exp5()
    % VERIFY_STEP50_EXP5 Tests Experiment 5 execution under conventional SMC
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp5_comparison_smc(1.0);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 50: FAIL - Experiment 5 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 50: FAIL - Experiment 5 state contains NaN or Inf');
    end
    
    fprintf('STEP 50: PASS\n');
end
