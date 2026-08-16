function verify_step23_single_auv_mb()
    % VERIFY_STEP23_SINGLE_AUV_MB Simulates 1 AUV tracking for 5s and checks boundedness & error decay
    
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
    X0 = [eta_init(:, 1); nu_init(:, 1)];
    
    tspan = [0, 5];
    options = odeset('RelTol', 1e-5, 'AbsTol', 1e-6, 'MaxStep', 5e-3);
    
    [t_out, X_out] = ode15s(@(t, X) rhs_single_auv_mb(t, X, params), tspan, X0, options);
    
    if any(isnan(X_out(:))) || any(isinf(X_out(:)))
        error('STEP 23: FAIL - Simulation state contains NaN or Inf');
    end
    
    % Check error decay
    [eta_d0, ~, ~] = reference_1608(t_out(end));
    offsets = formation_offsets();
    eta_final = X_out(end, 1:6)';
    chi_final = eta_final - eta_d0 - offsets(:, 1);
    
    if norm(chi_final(1:3)) > 1.0
        error('STEP 23: FAIL - Single AUV spatial error did not decrease under 5s');
    end
    
    fprintf('STEP 23: PASS\n');
end
