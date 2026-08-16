function verify_step27_antiwindup()
    % VERIFY_STEP27_ANTIWINDUP Tests anti-windup state derivative calculation and responsiveness
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    
    omega_aw = zeros(6, 1);
    s = [0.1; -0.1; 0.2; -0.05; 0.05; -0.01];
    delta_tau = [-50; 50; -10; 10; -2; 2]; % Nonzero saturation error
    
    omega_dot = antiwindup_rhs(omega_aw, s, delta_tau);
    
    if any(isnan(omega_dot)) || any(isinf(omega_dot))
        error('STEP 27: FAIL - antiwindup_rhs output contains NaN or Inf');
    end
    if norm(omega_dot - (s + delta_tau)) > 1e-12
        error('STEP 27: FAIL - antiwindup_rhs at zero state must equal s + delta_tau');
    end
    
    fprintf('STEP 27: PASS\n');
end
