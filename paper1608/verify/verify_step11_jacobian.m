function verify_step11_jacobian()
    % VERIFY_STEP11_JACOBIAN Tests J(0) == I_6, non-singularity, and inverse precision
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    
    % Test 1: At zero attitude J(0) == I_6
    J0 = jacobian_J(zeros(6, 1));
    if norm(J0 - eye(6)) > 1e-12
        error('STEP 11: FAIL - J(0) is not identity matrix');
    end
    
    % Test 2: Random non-singular attitude |\theta| < \pi/2
    eta_test = [1; 2; 3; 0.1; 0.2; -0.3];
    J = jacobian_J(eta_test);
    
    if abs(det(J)) < 1e-6
        error('STEP 11: FAIL - J is singular for normal attitude');
    end
    
    inv_err = norm(J * inv(J) - eye(6));
    if inv_err > 1e-10
        error('STEP 11: FAIL - Matrix inverse precision error exceeds 1e-10: %g', inv_err);
    end
    
    fprintf('STEP 11: PASS\n');
end
