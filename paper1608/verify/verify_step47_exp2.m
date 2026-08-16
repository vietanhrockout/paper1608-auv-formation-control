function verify_step47_exp2()
    % VERIFY_STEP47_EXP2 Tests Experiment 2 execution under actuator saturation
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    res = exp2_sat_no_antiwindup(1.0);
    
    if isempty(res.t) || isempty(res.X)
        error('STEP 47: FAIL - Experiment 2 produced empty results');
    end
    if any(isnan(res.X(:))) || any(isinf(res.X(:)))
        error('STEP 47: FAIL - Experiment 2 state contains NaN or Inf');
    end
    
    fprintf('STEP 47: PASS\n');
end
