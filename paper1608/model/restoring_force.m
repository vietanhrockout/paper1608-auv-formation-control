function g = restoring_force(eta)
    % RESTORING_FORCE Hydrostatic restoring force vector g(\eta)
    % \eta = [x, y, z, phi, theta, psi]^T
    
    p = auv_parameters();
    phi   = eta(4);
    theta = eta(5);
    
    W = p.W;
    B = p.B;
    zg = p.r_g(3);
    
    sphi = sin(phi);   cphi = cos(phi);
    sthe = sin(theta); cthe = cos(theta);
    
    g = [
        (W - B) * sthe;
        -(W - B) * cthe * sphi;
        -(W - B) * cthe * cphi;
        zg * W * cthe * sphi;
        zg * W * sthe;
        0
    ];
end
