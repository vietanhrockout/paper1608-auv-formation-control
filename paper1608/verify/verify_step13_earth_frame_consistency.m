function verify_step13_earth_frame_consistency()
    % VERIFY_STEP13_EARTH_FRAME_CONSISTENCY Compares body-transform acceleration with earth model
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    
    eta = [1; 2; -5; 0.1; -0.15; 0.2];
    nu  = [0.8; -0.3; 0.2; 0.02; -0.01; 0.03];
    tau_act = [10; -5; 8; 1; -2; 1.5];
    
    J = jacobian_J(eta);
    eta_dot = J * nu;
    
    eta_ddot1 = earth_frame_dynamics(eta, eta_dot, tau_act);
    
    Jdot = jacobian_Jdot(eta, eta_dot);
    [~, nu_dot] = auv_dynamics(eta, nu, tau_act);
    eta_ddot2 = Jdot * nu + J * nu_dot;
    
    diff_err = norm(eta_ddot1 - eta_ddot2);
    if diff_err > 1e-6
        error('STEP 13: FAIL - Earth-frame acceleration mismatch: %g', diff_err);
    end
    
    fprintf('STEP 13: PASS\n');
end
