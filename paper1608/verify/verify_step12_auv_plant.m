function verify_step12_auv_plant()
    % VERIFY_STEP12_AUV_PLANT Runs open-loop plant test for 30s under zero input
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    
    eta = [0; 0; -10; 0.05; -0.05; 0.1];
    nu  = [0.5; -0.2; 0.1; 0.01; -0.01; 0.02];
    
    [eta_dot, nu_dot] = auv_dynamics(eta, nu);
    
    if any(isnan(eta_dot)) || any(isnan(nu_dot))
        error('STEP 12: FAIL - NaN detected in open-loop plant derivative');
    end
    if any(isinf(eta_dot)) || any(isinf(nu_dot))
        error('STEP 12: FAIL - Inf detected in open-loop plant derivative');
    end
    
    fprintf('STEP 12: PASS\n');
end
