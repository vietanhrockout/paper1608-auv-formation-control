function verify_step19_f_true()
    % VERIFY_STEP19_F_TRUE Compares acceleration from f_true with earth_frame_dynamics under zero input
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'control'));
    
    eta = [1; -1; -8; 0.1; -0.05; 0.2];
    nu  = [0.6; -0.2; 0.1; 0.01; -0.02; 0.01];
    J = jacobian_J(eta);
    eta_dot = J * nu;
    
    f_val = f_true_drift(eta, eta_dot);
    eta_ddot_plant = earth_frame_dynamics(eta, eta_dot, zeros(6, 1));
    
    if norm(f_val - eta_ddot_plant) > 1e-5
        error('STEP 19: FAIL - f_true mismatch with open-loop plant acceleration under zero input');
    end
    
    fprintf('STEP 19: PASS\n');
end
