function V_hat = critic_output(chi_i, Wc_i, cfg)
    % CRITIC_OUTPUT Computes scalar Value function estimate \hat{V}_i(Z_i) (Eq. 14)
    % \hat{V}_i = \hat{w}_{ci}^T \theta_c(\chi_i)
    
    if nargin < 3 || isempty(cfg)
        cfg = nn_config();
    end
    
    theta_c = critic_basis(chi_i, cfg);
    V_hat = Wc_i' * theta_c;
end
