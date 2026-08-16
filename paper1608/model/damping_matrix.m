function D = damping_matrix(nu)
    % DAMPING_MATRIX Total hydrodynamic damping matrix D(v) = D_L + D_n(v)
    % nu = [u, v, w, p, q, r]^T
    
    p = auv_parameters();
    u = nu(1); v = nu(2); w = nu(3);
    p_rate = nu(4); q_rate = nu(5); r_rate = nu(6);
    
    % Linear damping
    D_L = -diag([p.Xu, p.Yv, p.Zw, p.Kp, p.Mq, p.Nr]);
    
    % Quadratic damping
    D_n = -diag([
        p.Xuu * abs(u), ...
        p.Yvv * abs(v), ...
        p.Zww * abs(w), ...
        p.Kpp * abs(p_rate), ...
        p.Mqq * abs(q_rate), ...
        p.Nrr * abs(r_rate)
    ]);

    D = D_L + D_n;
end
