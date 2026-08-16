function X = pack_states(eta_mat, nu_mat, omega_aw_mat, Wa_cell, Wc_mat, cfg)
    % PACK_STATES Packs states for 3 AUVs into a single 549x1 state vector
    % Per AUV state layout (183 states):
    %   1:6    : eta_i
    %   7:12   : nu_i
    %   13:18  : omega_aw_i
    %   19:168 : Wa_i (25x6 = 150 flattened column-wise)
    %   169:183: Wc_i (15x1)
    
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end
    
    m_a = cfg.actor_n_nodes; % 25
    m_c = cfg.critic_n_nodes; % 15
    n_per_auv = 18 + m_a * 6 + m_c; % 183
    
    X = zeros(n_per_auv * 3, 1);
    
    for i = 1:3
        idx_base = (i - 1) * n_per_auv;
        X(idx_base + (1:6))   = eta_mat(:, i);
        X(idx_base + (7:12))  = nu_mat(:, i);
        X(idx_base + (13:18)) = omega_aw_mat(:, i);
        
        Wa_flat = Wa_cell{i}(:);
        X(idx_base + 18 + (1:150)) = Wa_flat;
        X(idx_base + 168 + (1:15))  = Wc_mat(:, i);
    end
end
