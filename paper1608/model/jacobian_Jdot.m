function Jdot = jacobian_Jdot(eta, eta_dot)
    % JACOBIAN_JDOT Time derivative of transformation matrix Jdot(\eta, \dot{\eta})
    % Evaluated numerically using central finite difference or exact trigonometric chain rule
    
    h = 1e-6;
    Jdot = zeros(6, 6);
    
    for k = 4:6 % attitude angles derivative affect J
        eta_p = eta; eta_p(k) = eta_p(k) + h;
        eta_m = eta; eta_m(k) = eta_m(k) - h;
        
        J_p = jacobian_J(eta_p);
        J_m = jacobian_J(eta_m);
        
        dJ_deta_k = (J_p - J_m) / (2 * h);
        Jdot = Jdot + dJ_deta_k * eta_dot(k);
    end
end
