function verify_step07_negative_power()
    % VERIFY_STEP07_NEGATIVE_POWER Sweeps velocity from 1e-12 to 10 and checks magnitude bounds
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'math'));
    
    a = -0.2; % 1 - alpha1 where alpha1 = 1.2
    v_sweep = [1e-12, 1e-9, 1e-6, 1e-3, 0.1, 1.0, 10.0];
    
    % Test regularized mode
    y_reg = sigpow_negative(v_sweep, a, 'regularized', 1e-6);
    
    if any(isnan(y_reg))
        error('STEP 07: FAIL - Regularized negative power output contains NaN');
    end
    if any(isinf(y_reg))
        error('STEP 07: FAIL - Regularized negative power output contains Inf at near-zero');
    end
    if max(abs(y_reg)) > 1e6
        error('STEP 07: FAIL - Regularized output exceeded safety bound');
    end
    
    fprintf('STEP 07: PASS\n');
end
