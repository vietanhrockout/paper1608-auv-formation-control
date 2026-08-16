function verify_step04_paper_params()
    % VERIFY_STEP04_PAPER_PARAMS Verifies mathematical parameter constraints of Paper 1608
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    
    params = paper_params();
    
    % Check constraint 1: c > 1
    if ~(params.c > 1)
        error('STEP 04: FAIL - Constraint c > 1 violated: c = %g', params.c);
    end
    
    % Check constraint 2: 1 < alpha1 < 1.5
    if ~(params.alpha1 > 1 && params.alpha1 < 1.5)
        error('STEP 04: FAIL - Constraint 1 < alpha1 < 1.5 violated: alpha1 = %g', params.alpha1);
    end
    
    % Check constraint 3: zeta1 > 1
    if ~(params.zeta1 > 1)
        error('STEP 04: FAIL - Constraint zeta1 > 1 violated: zeta1 = %g', params.zeta1);
    end
    
    % Check constraint 4: zeta1 * zeta2 < 1
    z1z2 = params.zeta1 * params.zeta2;
    if ~(z1z2 < 1)
        error('STEP 04: FAIL - Constraint zeta1*zeta2 < 1 violated: zeta1*zeta2 = %g', z1z2);
    end
    
    % Check constraint 5: 1 < zeta1 * zeta3 < zeta1
    z1z3 = params.zeta1 * params.zeta3;
    if ~(z1z3 > 1 && z1z3 < params.zeta1)
        error('STEP 04: FAIL - Constraint 1 < zeta1*zeta3 < zeta1 violated: zeta1*zeta3 = %g', z1z3);
    end
    
    % Check constraint 6: 1/alpha1 < b1*c < 1
    b1c = params.b1 * params.c;
    inv_alpha1 = 1 / params.alpha1;
    if ~(inv_alpha1 < b1c && b1c < 1)
        error('STEP 04: FAIL - Constraint 1/alpha1 < b1*c < 1 violated: 1/alpha1 = %g, b1*c = %g', inv_alpha1, b1c);
    end
    
    % Check constraint 7: b2*c > 1
    b2c = params.b2 * params.c;
    if ~(b2c > 1)
        error('STEP 04: FAIL - Constraint b2*c > 1 violated: b2*c = %g', b2c);
    end
    
    fprintf('STEP 04: PASS\n');
end
