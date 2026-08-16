function is_valid = verify_predefined_time_bound(res, params)
    % VERIFY_PREDEFINED_TIME_BOUND Verifies that error tracking converges within T_max <= T1* + T2* = 10.0 s
    
    if nargin < 2 || isempty(params)
        params = paper_params();
    end
    
    T_max = params.T1star + params.T2star; % 10.0 s
    t = res.t;
    X = res.X;
    
    idx_after_Tmax = find(t >= T_max);
    if isempty(idx_after_Tmax)
        is_valid = false;
        return;
    end
    
    cfg = nn_config();
    is_valid = true;
    
    for idx = idx_after_Tmax(1):length(t)
        [eta_mat, ~, ~, ~, ~] = unpack_states(X(idx, :)', cfg);
        [eta_d0, ~, ~] = reference_1608(t(idx));
        offsets = formation_offsets();
        
        for i = 1:3
            chi_i = eta_mat(:, i) - eta_d0 - offsets(:, i);
            if norm(chi_i(1:3)) > 0.05 || norm(chi_i(4:6)) > 0.01
                is_valid = false;
                return;
            end
        end
    end
end
