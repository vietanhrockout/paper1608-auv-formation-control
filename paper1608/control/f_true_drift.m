function f = f_true_drift(eta, eta_dot)
    % F_TRUE_DRIFT Computes true physical unknown drift dynamics (Eq. 7)
    % f_i(\eta, \dot{\eta}) = -M_{0i}^{-1} (C_i\dot{\eta}_i + D_i\dot{\eta}_i + g_i)
    
    J = jacobian_J(eta);
    nu = inv(J) * eta_dot;
    
    M = mass_matrix();
    C = coriolis_matrix(nu);
    D = damping_matrix(nu);
    g = restoring_force(eta);
    
    % In Earth frame: M_eta = J^{-T} M J^{-1}
    % C_eta \dot{\eta} + D_eta \dot{\eta} + g_eta = J^{-T} (C v + D v + g) - J^{-T} M J^{-1} \dot{J} v
    Jdot = jacobian_Jdot(eta, eta_dot);
    
    body_forces = C * nu + D * nu + g - M * (inv(J) * Jdot * nu);
    
    M_eta = (J') \ M / J;
    f = -M_eta \ ((J') \ body_forces);
end
