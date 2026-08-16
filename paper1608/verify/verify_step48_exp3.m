function verify_step48_exp3()
    % VERIFY_STEP48_EXP3 Tests Experiment 3 execution with anti-windup
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp3_sat_antiwindup(1.0);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 48: FAIL - Experiment 3 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 48: FAIL - Experiment 3 state contains NaN or Inf');
    end
    
    fprintf('STEP 48: PASS\n');
end
