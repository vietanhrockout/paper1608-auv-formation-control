function [eta_d0, eta_d0_dot, eta_d0_ddot] = reference_1608(t)
    % REFERENCE_1608 Virtual Leader trajectory generator (Eq. 57)
    % \eta_d0(t) = [\sin(0.1t), -0.1t, -0.2t - 10, 0, 0, 0]^T
    
    eta_d0 = [
        sin(0.1 * t);
        -0.1 * t;
        -0.2 * t - 10;
        0;
        0;
        0
    ];
    
    eta_d0_dot = [
        0.1 * cos(0.1 * t);
        -0.1;
        -0.2;
        0;
        0;
        0
    ];
    
    eta_d0_ddot = [
        -0.01 * sin(0.1 * t);
        0;
        0;
        0;
        0;
        0
    ];
end
