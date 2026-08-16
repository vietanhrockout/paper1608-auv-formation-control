function dXdt = rhs_3auv_mb(t, X, params)
    % RHS_3AUV_MB System RHS for 3 AUVs model-based formation simulation
    % State vector X (36x1):
    %   X(1:6)   = eta_0,  X(7:12)  = nu_0
    %   X(13:18) = eta_1,  X(19:24) = nu_1
    %   X(25:30) = eta_2,  X(31:36) = nu_2
    
    if nargin < 3 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    dXdt = zeros(36, 1);
    
    for i_auv = 1:3
        idx_eta = (i_auv - 1) * 12 + (1:6);
        idx_nu  = (i_auv - 1) * 12 + (7:12);
        
        eta = X(idx_eta);
        nu  = X(idx_nu);
        
        J = jacobian_J(eta);
        eta_dot = J * nu;
        
        tau_cmd = controller_model_based(eta, eta_dot, t, i_auv, params);
        [eta_dot_plant, nu_dot_plant] = auv_dynamics(eta, nu, tau_cmd, zeros(6, 1));
        
        dXdt(idx_eta) = eta_dot_plant;
        dXdt(idx_nu)  = nu_dot_plant;
    end
end
