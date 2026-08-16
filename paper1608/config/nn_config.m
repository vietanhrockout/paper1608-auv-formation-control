function cfg = nn_config()
    % NN_CONFIG RBF Neural Network Architecture Parameters & Center Distributions
    
    cfg = struct();
    
    % --- Actor NN Configuration ---
    cfg.actor_nodes_per_dim = 5;
    cfg.actor_n_nodes = cfg.actor_nodes_per_dim * cfg.actor_nodes_per_dim; % 25 nodes
    cfg.actor_width = 5.0; % la = 5 (Table 1)
    
    grid_x1 = linspace(-10, 10, cfg.actor_nodes_per_dim);
    grid_x2 = linspace(-5, 5, cfg.actor_nodes_per_dim);
    [X1, X2] = meshgrid(grid_x1, grid_x2);
    cfg.actor_centers = [X1(:)'; X2(:)']; % 2 x 25 matrix
    
    % Weight projection upper bound for Actor
    cfg.delta_a = 50.0;
    cfg.actor_weight_bound = cfg.delta_a; % Alias for backward compatibility
    
    % --- Critic NN Configuration ---
    cfg.critic_n_nodes = 15;
    cfg.critic_width = 5.0; % lc = 5 (Table 1)
    
    % 6D centers for Critic tracking error \chi_i
    rng(1); % Seeded for reproducibility
    cfg.critic_centers = -5 + 10 * rand(6, cfg.critic_n_nodes); % 6 x 15 matrix
    
    % Weight projection upper bound for Critic
    cfg.delta_c = 100.0;
    cfg.critic_weight_bound = cfg.delta_c; % Alias for backward compatibility
    
    % --- Initial Weights ---
    cfg.initial_Wa = zeros(cfg.actor_n_nodes, 6, 3);  % m_a x 6 DOFs x 3 AUVs
    cfg.initial_Wc = zeros(cfg.critic_n_nodes, 3);    % m_c x 3 AUVs
end
