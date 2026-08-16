function C = coriolis_matrix(nu)
    % CORIOLIS_MATRIX Coriolis-centripetal matrix C(v) for 6-DOF AUV
    % nu = [u, v, w, p, q, r]^T
    
    p = auv_parameters();
    u = nu(1); v = nu(2); w = nu(3);
    p_rate = nu(4); q_rate = nu(5); r_rate = nu(6);
    
    m11 = p.m11; m22 = p.m22; m33 = p.m33;
    m44 = p.m44; m55 = p.m55; m66 = p.m66;
    
    C = zeros(6, 6);
    
    % C12 block
    C(1, 4) = 0;             C(1, 5) = m33 * w;       C(1, 6) = -m22 * v;
    C(2, 4) = -m33 * w;      C(2, 5) = 0;             C(2, 6) = m11 * u;
    C(3, 4) = m22 * v;       C(3, 5) = -m11 * u;      C(3, 6) = 0;
    
    % C21 block
    C(4, 1) = 0;             C(4, 2) = m33 * w;       C(4, 3) = -m22 * v;
    C(5, 1) = -m33 * w;      C(5, 2) = 0;             C(5, 3) = m11 * u;
    C(6, 1) = m22 * v;       C(6, 2) = -m11 * u;      C(6, 3) = 0;
    
    % C22 block
    C(4, 5) = m66 * r_rate;  C(4, 6) = -m55 * q_rate;
    C(5, 4) = -m66 * r_rate; C(5, 6) = m44 * p_rate;
    C(6, 4) = m55 * q_rate;  C(6, 5) = -m44 * p_rate;
end
