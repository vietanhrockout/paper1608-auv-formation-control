function theta_a = actor_basis(chi_j, vel_err_j, cfg)
    % ACTOR_BASIS Computes Actor RBF basis activations for single DOF j (Eq. 32)
    % Input vector: \bar{x}_{aij} = [\chi_{ij}, \upsilon_{ij}]^T
    
    if nargin < 3 || isempty(cfg)
        cfg = nn_config();
    end
    
    x_actor_j = [chi_j; vel_err_j];
    theta_a = rbf_gaussian(x_actor_j, cfg.actor_centers, cfg.actor_width);
end
