function verify_step18_sliding_surface()
    % VERIFY_STEP18_SLIDING_SURFACE Checks s = 0 when chi = 0 and vel_err = 0
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    
    chi_zero = zeros(6, 1);
    vel_err_zero = zeros(6, 1);
    
    s = sliding_surface(chi_zero, vel_err_zero);
    
    if norm(s) > 1e-12
        error('STEP 18: FAIL - Sliding surface s is not zero when chi=0 and vel_err=0');
    end
    
    fprintf('STEP 18: PASS\n');
end
