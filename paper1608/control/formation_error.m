function [chi, vel_err] = formation_error(eta, eta_dot, t, i_auv)
    % FORMATION_ERROR Position and velocity tracking error vectors for i-th AUV
    % \chi_i = \eta_i - \eta_d0 - \eta_l0i (Eq. 5)
    % \upsilon_i = \dot{\eta}_i - \dot{\bar{\eta}}_d0 (Eq. 6)
    
    if nargin < 4 || isempty(i_auv)
        i_auv = 1;
    end
    
    offsets = formation_offsets();
    eta_l0i = offsets(:, i_auv);
    
    [eta_d0, eta_d0_dot, ~] = reference_1608(t);
    
    chi = eta - eta_d0 - eta_l0i;
    vel_err = eta_dot - eta_d0_dot;
end
