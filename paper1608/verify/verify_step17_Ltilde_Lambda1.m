function verify_step17_Ltilde_Lambda1()
    % VERIFY_STEP17_LTILDE_LAMBDA1 Compares analytic L + Ltilde with finite-difference d/dchi [L(chi)*chi]
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'control'));
    
    params = paper_params();
    params = derived_params(params);
    
    chi_test = [2.0; -1.5; 0.8; -0.3; 0.1; -0.05];
    vel_err_test = [0.5; -0.2; 0.1; -0.01; 0.05; -0.02];
    
    L = gain_matrix_L(chi_test, params);
    Ltilde = gain_matrix_Ltilde(chi_test, params);
    analytic_sum = L + Ltilde;
    
    % Finite difference calculation of d/dchi [L(chi)*chi] for each DOF
    h = 1e-6;
    fd_diag = zeros(6, 1);
    for j = 1:6
        chi_p = chi_test; chi_p(j) = chi_p(j) + h;
        chi_m = chi_test; chi_m(j) = chi_m(j) - h;
        
        L_p = gain_matrix_L(chi_p, params);
        L_m = gain_matrix_L(chi_m, params);
        
        val_p = L_p(j, j) * chi_p(j);
        val_m = L_m(j, j) * chi_m(j);
        
        fd_diag(j) = (val_p - val_m) / (2 * h);
    end
    
    rel_err = max(abs(diag(analytic_sum) - fd_diag) ./ abs(fd_diag));
    if rel_err > 1e-3
        error('STEP 17: FAIL - Analytic (L + Ltilde) mismatch with finite difference: rel_err = %g', rel_err);
    end
    
    Lambda1 = matrix_Lambda1(vel_err_test, params);
    if any(diag(Lambda1) < 0)
        error('STEP 17: FAIL - Lambda1 matrix diagonal elements must be non-negative');
    end
    
    fprintf('STEP 17: PASS\n');
end
