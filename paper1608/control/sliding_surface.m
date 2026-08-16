function s = sliding_surface(chi, vel_err, params)
    % SLIDING_SURFACE Nonsingular Predefined-Time Terminal Sliding Surface s_i (Eq. 21)
    % s_i = L(\chi_i)\chi_i + sig^{\alpha_1}(\upsilon_i)
    
    if nargin < 3 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    L = gain_matrix_L(chi, params);
    sig_v = sigpow(vel_err, params.alpha1);
    
    s = L * chi + sig_v;
end
