function verify_step09_initial_conditions()
    % VERIFY_STEP09_INITIAL_CONDITIONS Evaluates formation tracking errors at t=0
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'reference'));
    
    [eta_init, nu_init] = initial_conditions();
    offsets = formation_offsets();
    [eta_d0, ~, ~] = reference_1608(0);
    
    % Compute initial position tracking errors: \chi_i = \eta_i - \eta_d0 - \eta_l0i
    chi = zeros(6, 3);
    for i = 1:3
        chi(:, i) = eta_init(:, i) - eta_d0 - offsets(:, i);
    end
    
    % Check AUV0: [6, 6, 6] - [0, 0, -10] - [0, 0, 0] = [6, 6, 16, 0, 0, 0]
    if norm(chi(:, 1) - [6; 6; 16; 0; 0; 0]) > 1e-12
        error('STEP 09: FAIL - Initial tracking error chi_0 mismatch');
    end
    
    % Check AUV1: [1, 1, 4] - [0, 0, -10] - [3, 4, 2] = [-2, -3, 12, 0, 0, 0]
    if norm(chi(:, 2) - [-2; -3; 12; 0; 0; 0]) > 1e-12
        error('STEP 09: FAIL - Initial tracking error chi_1 mismatch');
    end
    
    % Check AUV2: [0, 2, 2] - [0, 0, -10] - [6, 1, 4] = [-6, 1, 8, 0, 0, 0]
    if norm(chi(:, 3) - [-6; 1; 8; 0; 0; 0]) > 1e-12
        error('STEP 09: FAIL - Initial tracking error chi_2 mismatch');
    end
    
    fprintf('STEP 09: PASS\n');
end
