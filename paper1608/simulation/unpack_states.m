function [eta_mat, nu_mat, omega_aw_mat, Wa_cell, Wc_mat] = unpack_states(X, cfg)
    % UNPACK_STATES Unpacks 549x1 state vector into structured per-AUV state matrices/cells
    % Pure, transparent state extraction without artificial state clipping (Issue J Resolved)
    
    if nargin < 2 || isempty(cfg)
        cfg = nn_config();
    end
    
    m_a = cfg.actor_n_nodes;  % 25
    m_c = cfg.critic_n_nodes; % 15
    n_per_auv = 18 + m_a * 6 + m_c; % 183
    
    eta_mat      = zeros(6, 3);
    nu_mat       = zeros(6, 3);
    omega_aw_mat = zeros(6, 3);
    Wa_cell      = cell(1, 3);
    Wc_mat       = zeros(m_c, 3);
    
    for i = 1:3
        idx_base = (i - 1) * n_per_auv;
        
        eta_mat(:, i)      = X(idx_base + (1:6));
        nu_mat(:, i)       = X(idx_base + (7:12));
        omega_aw_mat(:, i) = X(idx_base + (13:18));
        
        Wa_flat            = X(idx_base + 18 + (1:m_a * 6));
        Wa_cell{i}         = reshape(Wa_flat, [m_a, 6]);
        Wc_mat(:, i)       = X(idx_base + 18 + m_a * 6 + (1:m_c));
    end
end
