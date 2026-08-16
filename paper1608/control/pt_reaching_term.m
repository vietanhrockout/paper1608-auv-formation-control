function q = pt_reaching_term(s, params)
    % PT_REACHING_TERM Evaluates predefined-time reaching law vector (Eq. 25/31)
    % q(s) = sig^{\varsigma_1} ( \sigma_1 sig^{\varsigma_2}(s) + \sigma_2 sig^{\varsigma_3}(s) )
    
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    z1 = params.zeta1;
    z2 = params.zeta2;
    z3 = params.zeta3;
    
    sig_z2 = sigpow(s, z2);
    sig_z3 = sigpow(s, z3);
    
    inner = params.sigma1 * sig_z2 + params.sigma2 * sig_z3;
    q = sigpow(inner, z1);
end
