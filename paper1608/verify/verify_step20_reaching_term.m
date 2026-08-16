function verify_step20_reaching_term()
    % VERIFY_STEP20_REACHING_TERM Tests positive gains and q(s) sign alignment with s
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    
    params = simulation_params();
    
    if params.sigma1 <= 0 || params.sigma2 <= 0
        error('STEP 20: FAIL - Reaching law parameters sigma1, sigma2 must be positive');
    end
    
    s_test = [-2; -0.5; 0; 0.5; 2; 5];
    q = pt_reaching_term(s_test, params);
    
    if any(isnan(q)) || any(isinf(q))
        error('STEP 20: FAIL - Reaching term output contains NaN or Inf');
    end
    if any(sign(q) ~= sign(s_test))
        error('STEP 20: FAIL - Reaching term sign must align with sliding variable s');
    end
    
    fprintf('STEP 20: PASS\n');
end
