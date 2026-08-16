function res = exp3_sat_antiwindup(t_final, params, sat_cfg)
    % EXP3_SAT_ANTIWINDUP Experiment 3: Actuator Saturation WITH Adaptive Anti-Windup
    
    if nargin < 1 || isempty(t_final)
        t_final = 20.0;
    end
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    if nargin < 3 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    
    [eta_init, nu_init] = initial_conditions();
    X0 = zeros(54, 1); % 3 AUVs x (6 eta + 6 nu + 6 omega_aw)
    for i = 1:3
        X0((i-1)*18 + (1:6))  = eta_init(:, i);
        X0((i-1)*18 + (7:12)) = nu_init(:, i);
        X0((i-1)*18 + (13:18)) = zeros(6, 1);
    end
    
    tspan = [0, t_final];
    options = odeset('RelTol', 1e-4, 'AbsTol', 1e-5, 'MaxStep', 1e-2);
    
    [t_out, X_out] = ode15s(@(t, X) rhs_3auv_sat_aw(t, X, params, sat_cfg), tspan, X0, options);
    
    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.name = 'Exp3_Sat_Antiwindup';
end

function dXdt = rhs_3auv_sat_aw(t, X, params, sat_cfg)
    dXdt = zeros(54, 1);
    for i_auv = 1:3
        idx_eta = (i_auv - 1) * 18 + (1:6);
        idx_nu  = (i_auv - 1) * 18 + (7:12);
        idx_aw  = (i_auv - 1) * 18 + (13:18);
        
        eta = X(idx_eta);
        nu  = X(idx_nu);
        omega_aw = X(idx_aw);
        
        J = jacobian_J(eta);
        eta_dot = J * nu;
        
        [chi, vel_err] = formation_error(eta, eta_dot, t, i_auv);
        s = sliding_surface(chi, vel_err, params);
        
        tau_cmd = controller_model_based(eta, eta_dot, t, i_auv, params) + params.k2 * omega_aw;
        [tau_act, delta_tau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
        tau_d = ocean_disturbance(t, i_auv);
        
        [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_act, tau_d);
        omega_dot = antiwindup_rhs(omega_aw, s, delta_tau, params);
        
        dXdt(idx_eta) = eta_dot_plant;
        dXdt(idx_nu)  = nu_dot_plant;
        dXdt(idx_aw)  = omega_dot;
    end
end
