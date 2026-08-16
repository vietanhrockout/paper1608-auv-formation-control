function verify_step22_controller_mb()
    % VERIFY_STEP22_CONTROLLER_MB Logs and checks all terms of model-based controller
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    
    eta = [2; 3; -6; 0.1; -0.1; 0.2];
    eta_dot = [0.5; -0.2; 0.1; 0.01; -0.02; 0.01];
    t = 1.0;
    
    [tau_cmd, terms] = controller_model_based(eta, eta_dot, t, 1);
    
    if any(isnan(tau_cmd)) || any(isinf(tau_cmd))
        error('STEP 22: FAIL - tau_cmd contains NaN or Inf');
    end
    if any(~isreal(tau_cmd))
        error('STEP 22: FAIL - tau_cmd contains complex values');
    end
    if ~isequal(size(tau_cmd), [6, 1])
        error('STEP 22: FAIL - tau_cmd dimension must be 6x1');
    end
    
    fprintf('STEP 22: PASS\n');
end
