function verify_step25_saturation()
    % VERIFY_STEP25_SATURATION Tests clipping precision and identity tau_act == tau_cmd + delta_tau
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'math'));
    
    tau_cmd = [200; -200; 50; -50; 10; -10];
    tau_min = -[150; 150; 150; 30; 30; 30];
    tau_max = [150; 150; 150; 30; 30; 30];
    
    [tau_act, delta_tau] = sat_vector(tau_cmd, tau_min, tau_max);
    
    % Check bounds
    if any(tau_act > tau_max + 1e-12) || any(tau_act < tau_min - 1e-12)
        error('STEP 25: FAIL - Saturated output exceeded saturation bounds');
    end
    
    % Check identity tau_act == tau_cmd + delta_tau
    identity_err = norm(tau_act - (tau_cmd + delta_tau));
    if identity_err > 1e-12
        error('STEP 25: FAIL - Identity tau_act == tau_cmd + delta_tau violated');
    end
    
    fprintf('STEP 25: PASS\n');
end
