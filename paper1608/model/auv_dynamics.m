function [eta_dot, nu_dot] = auv_dynamics(eta, nu, tau_act, tau_dist)
    % AUV_DYNAMICS Open-loop 6-DOF AUV plant state derivatives in Body & Earth frames
    % M \dot{v} + C(v)v + D(v)v + g(\eta) = \tau_{act} + \tau_{dist}
    % \dot{\eta} = J(\eta) v
    
    if nargin < 3 || isempty(tau_act)
        tau_act = zeros(6, 1);
    end
    if nargin < 4 || isempty(tau_dist)
        tau_dist = zeros(6, 1);
    end
    
    M = mass_matrix();
    C = coriolis_matrix(nu);
    D = damping_matrix(nu);
    g = restoring_force(eta);
    J = jacobian_J(eta);
    
    nu_dot = M \ (tau_act + tau_dist - C * nu - D * nu - g);
    eta_dot = J * nu;
end
