function omega_dot = antiwindup_rhs(omega_aw, s, delta_tau, params)
    % ANTIVINDUP_RHS Auxiliary anti-windup state derivative \dot{\varpi}_i (Eq. 30)
    % \dot{\varpi}_i = -k_2 \varpi_i - sig^{\varsigma_1} ( \sigma_3 sig^{\varsigma_2}(\varpi_i) + \sigma_4 sig^{\varsigma_3}(\varpi_i) ) + s_i + \Delta\tau_i
    
    if nargin < 4 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    z1 = params.zeta1;
    z2 = params.zeta2;
    z3 = params.zeta3;
    
    sig_w_z2 = sigpow(omega_aw, z2);
    sig_w_z3 = sigpow(omega_aw, z3);
    
    inner = params.sigma3 * sig_w_z2 + params.sigma4 * sig_w_z3;
    pt_w = sigpow(inner, z1);
    
    omega_dot = -params.k2 * omega_aw - pt_w + s + delta_tau;
end
