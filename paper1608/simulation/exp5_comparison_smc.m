function res = exp5_comparison_smc(t_final, params, sat_cfg)
    % EXP5_COMPARISON_SMC Experiment 5: Conventional Finite-Time SMC Baseline
    
    if nargin < 1 || isempty(t_final)
        t_final = 20.0;
    end
    if nargin < 2 || isempty(params)
        params = paper_params();
    end
    if nargin < 3 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    
    [eta_init, nu_init] = initial_conditions();
    X0 = zeros(36, 1);
    for i = 1:3
        X0((i-1)*12 + (1:6))  = eta_init(:, i);
        X0((i-1)*12 + (7:12)) = nu_init(:, i);
    end
    
    tspan = [0, t_final];
    options = odeset('RelTol', 1e-4, 'AbsTol', 1e-5, 'MaxStep', 1e-2);
    
    [t_out, X_out] = ode15s(@(t, X) rhs_3auv_conventional_smc(t, X, params, sat_cfg), tspan, X0, options);
    
    res = struct();
    res.t = t_out;
    res.X = X_out;
    res.name = 'Exp5_Conventional_SMC';
end

function dXdt = rhs_3auv_conventional_smc(t, X, params, sat_cfg)
    dXdt = zeros(36, 1);
    for i_auv = 1:3
        idx_eta = (i_auv - 1) * 12 + (1:6);
        idx_nu  = (i_auv - 1) * 12 + (7:12);
        
        eta = X(idx_eta);
        nu  = X(idx_nu);
        
        J = jacobian_J(eta);
        eta_dot = J * nu;
        
        [chi, vel_err] = formation_error(eta, eta_dot, t, i_auv);
        s_conv = vel_err + 0.5 * sigpow(chi, 0.8);
        
        [~, ~, eta_d0_ddot] = reference_1608(t);
        v_acc = eta_d0_ddot - 0.5 * 0.8 * (abs(chi).^-(0.2)) .* vel_err - 2.0 * sign(s_conv);
        
        M = mass_matrix();
        tau_cmd = (J') * ((J') \ (M * ((J) \ v_acc)));
        [tau_act, ~] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
        tau_d = ocean_disturbance(t, i_auv);
        
        [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_act, tau_d);
        
        dXdt(idx_eta) = eta_dot_plant;
        dXdt(idx_nu)  = nu_dot_plant;
    end
end
