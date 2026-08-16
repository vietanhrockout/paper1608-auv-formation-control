function res = exp0_ideal_mb(t_final, params)
    % EXP0_IDEAL_MB Experiment 0: Ideal Model-Based PT-SMC (no disturbance, no saturation)
    
    if nargin < 1 || isempty(t_final)
        t_final = 20.0;
    end
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    [eta_init, nu_init] = initial_conditions();
    X0 = zeros(36, 1);
    for i = 1:3
        X0((i-1)*12 + (1:6))  = eta_init(:, i);
        X0((i-1)*12 + (7:12)) = nu_init(:, i);
    end
    
    tspan = [0, t_final];
    options = odeset('RelTol', 1e-4, 'AbsTol', 1e-5, 'MaxStep', 1e-2);
    
    [t_out, X_out] = ode15s(@(t, X) rhs_3auv_mb(t, X, params), tspan, X0, options);
    
    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.name = 'Exp0_Ideal_MB';
end
