function p = auv_parameters()
    % AUV_PARAMETERS Physical and hydrodynamic constants for 6-DOF AUV (Ref [43])
    
    p = struct();
    
    % Mass and geometry
    p.m = 18.5;       % Total mass (kg)
    p.g = 9.81;       % Gravity acceleration (m/s^2)
    p.W = p.m * p.g;  % Weight (N)
    p.B = p.m * p.g;  % Buoyancy (N) - neutrally buoyant
    
    % Center of gravity and buoyancy
    p.r_g = [0; 0; 0.01]; % CG position in body frame [xg, yg, zg]
    p.r_b = [0; 0; 0];    % CB position in body frame [xb, yb, zb]
    
    % Rigid-body inertia
    p.Ix = 0.23;
    p.Iy = 0.85;
    p.Iz = 0.85;
    
    % Added mass coefficients
    p.X_udot = -1.23;
    p.Y_vdot = -2.4;
    p.Z_wdot = -2.4;
    p.K_pdot = -0.04;
    p.M_qdot = -0.21;
    p.N_rdot = -0.21;
    
    % Diagonal elements of mass matrix M = M_RB + M_A
    p.m11 = p.m - p.X_udot; % 19.73
    p.m22 = p.m - p.Y_vdot; % 20.90
    p.m33 = p.m - p.Z_wdot; % 20.90
    p.m44 = p.Ix - p.K_pdot; % 0.27
    p.m55 = p.Iy - p.M_qdot; % 1.06
    p.m66 = p.Iz - p.N_rdot; % 1.06
    
    % Linear damping
    p.Xu = -1.62;
    p.Yv = -13.1;
    p.Zw = -13.1;
    p.Kp = -0.15;
    p.Mq = -0.68;
    p.Nr = -0.68;
    
    % Quadratic damping
    p.Xuu = -2.85;
    p.Yvv = -17.8;
    p.Zww = -17.8;
    p.Kpp = -0.008;
    p.Mqq = -0.22;
    p.Nrr = -0.22;
end
