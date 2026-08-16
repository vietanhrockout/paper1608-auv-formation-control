function r_i = strategic_utility(chi_i, tau_i, B, R)
    % STRATEGIC_UTILITY Computes instantaneous cost/utility function r_i(t) (Eq. 16)
    % r_i(t) = (\eta_i - \bar{\eta}_{0i}^d)^T B (\eta_i - \bar{\eta}_{0i}^d) + \tau_i^T R \tau_i
    %        = \chi_i^T B \chi_i + \tau_i^T R \tau_i
    
    if nargin < 3 || isempty(B)
        B = eye(6);
    end
    if nargin < 4 || isempty(R)
        R = 1e-4 * eye(6);
    end
    
    r_i = (chi_i') * B * chi_i + (tau_i') * R * tau_i;
end
