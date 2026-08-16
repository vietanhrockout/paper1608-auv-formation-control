function verify_step08_reference()
    % VERIFY_STEP08_REFERENCE Verifies reference derivatives against central finite differences
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'reference'));
    
    t_test = 5.0;
    h = 1e-6;
    
    [eta0, eta0_dot, eta0_ddot] = reference_1608(t_test);
    [eta_plus, ~, ~]            = reference_1608(t_test + h);
    [eta_minus, ~, ~]           = reference_1608(t_test - h);
    
    num_dot = (eta_plus - eta_minus) / (2 * h);
    
    if max(abs(eta0_dot - num_dot)) > 1e-5
        error('STEP 08: FAIL - Analytic eta_dot mismatch with finite difference');
    end
    
    [~, eta_dot_plus, ~]  = reference_1608(t_test + h);
    [~, eta_dot_minus, ~] = reference_1608(t_test - h);
    num_ddot = (eta_dot_plus - eta_dot_minus) / (2 * h);
    
    if max(abs(eta0_ddot - num_ddot)) > 1e-5
        error('STEP 08: FAIL - Analytic eta_ddot mismatch with finite difference');
    end
    
    fprintf('STEP 08: PASS\n');
end
