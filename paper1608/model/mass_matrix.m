function M = mass_matrix()
    % MASS_MATRIX Returns total mass matrix M = M_RB + M_A for 6-DOF AUV
    p = auv_parameters();
    M = diag([p.m11, p.m22, p.m33, p.m44, p.m55, p.m66]);
end
