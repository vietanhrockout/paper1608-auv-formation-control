function verify_step35_utility()
    % VERIFY_STEP35_UTILITY Verifies strategic utility cost function r_i(t) (Paper Eq. 16)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'control'));
    
    chi_i = [1; -1; 0.5; -0.1; 0.05; -0.01];
    tau_i = [10; -10; 5; -1; 0.5; -0.2];
    
    r_i = strategic_utility(chi_i, tau_i);
    
    if isnan(r_i) || isinf(r_i) || ~isreal(r_i)
        error('STEP 35: FAIL - Strategic utility r_i is not a valid real scalar');
    end
    if r_i <= 0
        error('STEP 35: FAIL - Strategic utility r_i must be strictly positive for non-zero tracking error and control input');
    end
    
    fprintf('STEP 35: PASS\n');
end
