function verify_step24_3auv_mb()
    % VERIFY_STEP24_3AUV_MB Simulates 3 AUVs model-based formation and checks spatial offset convergence
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'simulation'));
    
    params = paper_params();
    params = derived_params(params);
    
    [eta_init, nu_init] = initial_conditions();
    X0 = zeros(36, 1);
    for i = 1:3
        X0((i-1)*12 + (1:6))  = eta_init(:, i);
        X0((i-1)*12 + (7:12)) = nu_init(:, i);
    end
    
    tspan = [0, 5];
    options = odeset('RelTol', 1e-5, 'AbsTol', 1e-6, 'MaxStep', 5e-3);
    
    [t_out, X_out] = ode15s(@(t, X) rhs_3auv_mb(t, X, params), tspan, X0, options);
    
    if any(isnan(X_out(:))) || any(isinf(X_out(:)))
        error('STEP 24: FAIL - 3 AUV simulation state contains NaN or Inf');
    end
    
    % Check spatial offsets convergence to [3, 4, 2] for AUV1 and [6, 1, 4] for AUV2
    eta0_end = X_out(end, 1:6)';
    eta1_end = X_out(end, 13:18)';
    eta2_end = X_out(end, 25:30)';
    
    dist10_end = eta1_end(1:3) - eta0_end(1:3);
    dist20_end = eta2_end(1:3) - eta0_end(1:3);
    
    if norm(dist10_end - [3; 4; 2]) > 1.0
        error('STEP 24: FAIL - AUV1 relative distance to leader did not converge toward [3, 4, 2]');
    end
    if norm(dist20_end - [6; 1; 4]) > 1.0
        error('STEP 24: FAIL - AUV2 relative distance to leader did not converge toward [6, 1, 4]');
    end
    
    fprintf('STEP 24: PASS\n');
end
