function verify_step36_bellman_error()
    % VERIFY_STEP36_BELLMAN_ERROR Verifies Bellman error c_{ei} (Paper Eq. 17)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    
    chi_i = [1; -1; 0.5; -0.1; 0.05; -0.01];
    vel_err_i = [0.1; -0.05; 0.02; -0.01; 0.005; -0.002];
    Wc_i = zeros(15, 1);
    tau_i = [10; -10; 5; -1; 0.5; -0.2];
    
    [c_ei, Phi_i] = bellman_error(chi_i, vel_err_i, Wc_i, tau_i);
    
    if isnan(c_ei) || isinf(c_ei) || ~isreal(c_ei)
        error('STEP 36: FAIL - Bellman error c_ei is not a valid real scalar');
    end
    if ~isequal(size(Phi_i), [15, 1])
        error('STEP 36: FAIL - Regressor Phi_i dimension must be 15x1');
    end
    
    fprintf('STEP 36: PASS\n');
end
