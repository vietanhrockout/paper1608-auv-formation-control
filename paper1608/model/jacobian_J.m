function J = jacobian_J(eta)
    % JACOBIAN_J Kinematic transformation matrix J(\eta) from Body to Earth frame
    % \eta = [x, y, z, phi, theta, psi]^T
    
    phi   = eta(4);
    theta = eta(5);
    psi   = eta(6);
    
    cphi = cos(phi);   sphi = sin(phi);
    cthe = cos(theta); sthe = sin(theta);
    cpsi = cos(psi);   spsi = sin(psi);
    tthe = tan(theta);
    
    % Prevent division by zero if theta approaches +/- pi/2
    if abs(cthe) < 1e-6
        cthe = sign(cthe) * 1e-6;
    end
    
    J1 = [
        cpsi*cthe, -spsi*cphi + cpsi*sthe*sphi,  spsi*sphi + cpsi*sthe*cphi;
        spsi*cthe,  cpsi*cphi + spsi*sthe*sphi, -cpsi*sphi + spsi*sthe*cphi;
        -sthe,      cthe*sphi,                  cthe*cphi
    ];

    J2 = [
        1,  sphi*tthe,  cphi*tthe;
        0,  cphi,      -sphi;
        0,  sphi/cthe,  cphi/cthe
    ];

    J = zeros(6, 6);
    J(1:3, 1:3) = J1;
    J(4:6, 4:6) = J2;
end
