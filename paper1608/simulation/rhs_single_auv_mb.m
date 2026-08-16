function dXdt = rhs_single_auv_mb(t, X, params)
    % RHS_SINGLE_AUV_MB System RHS for 1 AUV tracking virtual leader under ideal model-based PT-SMC
    % State vector X (12x1):
    %   X(1:6)  = eta_0
    %   X(7:12) = nu_0
    
    if nargin < 3 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    eta = X(1:6);
    nu  = X(7:12);
    
    J = jacobian_J(eta);
    eta_dot = J * nu;
    
    % Model-based controller command (ideal, unsaturated, no disturbance)
    tau_cmd = controller_model_based(eta, eta_dot, t, 1, params);
    
    [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_cmd, zeros(6, 1));
    
    dXdt = [eta_dot_plant; nu_dot_plant];
end
