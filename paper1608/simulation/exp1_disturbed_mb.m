function res = exp1_disturbed_mb(t_final, params)
    % EXP1_DISTURBED_MB Experiment 1: Disturbed Model-Based PT-SMC (with tau_d, no saturation)
    
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
    
    [t_out, X_out] = ode15s(@(t, X) rhs_3auv_mb_disturbed(t, X, params), tspan, X0, options);
    
    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.name = 'Exp1_Disturbed_MB';
end

function dXdt = rhs_3auv_mb_disturbed(t, X, params)
    dXdt = zeros(36, 1);
    for i_auv = 1:3
        idx_eta = (i_auv - 1) * 12 + (1:6);
        idx_nu  = (i_auv - 1) * 12 + (7:12);
        
        eta = X(idx_eta);
        nu  = X(idx_nu);
        
        J = jacobian_J(eta);
        eta_dot = J * nu;
        
        tau_cmd = controller_model_based(eta, eta_dot, t, i_auv, params);
        tau_d = ocean_disturbance(t, i_auv);
        
        [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_cmd, tau_d);
        
        dXdt(idx_eta) = eta_dot_plant;
        dXdt(idx_nu)  = nu_dot_plant;
    end
end
