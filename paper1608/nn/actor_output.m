function f_rl = actor_output(chi, vel_err, Wa_i, cfg)
    % ACTOR_OUTPUT Computes Actor estimated drift output vector f_{iRL} (Eq. 32)
    % f_{iRL, j} = \hat{w}_{aij}^T \theta_{aij}( \chi_{ij}, \upsilon_{ij} )
    
    if nargin < 4 || isempty(cfg)
        cfg = nn_config();
    end
    
    f_rl = zeros(6, 1);
    for j = 1:6
        % Correct indexing: Pass vel_err(j) (velocity error component j)
        th_aj = actor_basis(chi(j), vel_err(j), cfg);
        f_rl(j) = Wa_i(:, j)' * th_aj;
    end
end
