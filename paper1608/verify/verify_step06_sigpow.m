function verify_step06_sigpow()
    % VERIFY_STEP06_SIGPOW Tests sigpow operator for odd symmetry, real outputs, and zero values
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'math'));
    
    test_inputs = [-4, -1, -0.5, 0, 0.5, 1, 4];
    powers = [0.1, 0.5, 1.0, 1.2, 2.0];
    
    for a = powers
        y = sigpow(test_inputs, a);
        
        if any(~isreal(y))
            error('STEP 06: FAIL - Complex output detected for power %g', a);
        end
        if any(isnan(y))
            error('STEP 06: FAIL - NaN detected for power %g', a);
        end
        
        % Test odd symmetry sig^a(-x) == -sig^a(x)
        y_pos = sigpow([0.5, 1, 4], a);
        y_neg = sigpow([-0.5, -1, -4], a);
        if max(abs(y_pos + y_neg)) > 1e-12
            error('STEP 06: FAIL - Odd symmetry violated for power %g', a);
        end
    end
    
    % Test zero input
    if sigpow(0, 0.5) ~= 0
        error('STEP 06: FAIL - sigpow(0, a) must equal 0');
    end
    
    fprintf('STEP 06: PASS\n');
end
