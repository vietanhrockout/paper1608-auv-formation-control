function theta_c = critic_basis(chi_i, cfg)
    % CRITIC_BASIS Computes Critic RBF basis activations for 6D tracking error \chi_i (Eq. 14)
    % Input vector: Z_i = \chi_i (Issue F audited mapping)
    
    if nargin < 2 || isempty(cfg)
        cfg = nn_config();
    end
    
    theta_c = rbf_gaussian(chi_i, cfg.critic_centers, cfg.critic_width);
end
