function eta_ddot = earth_frame_dynamics(eta, eta_dot, tau_act, tau_dist)
    % EARTH_FRAME_DYNAMICS Reconstructs \ddot{\eta} directly in Earth frame
    % M_\eta \ddot{\eta} + C_\eta \dot{\eta} + D_\eta \dot{\eta} + g_\eta = J^{-T} \tau_{act} + \tau_{dist}
    
    if nargin < 3 || isempty(tau_act)
        tau_act = zeros(6, 1);
    end
    if nargin < 4 || isempty(tau_dist)
        tau_dist = zeros(6, 1);
    end
    
    J = jacobian_J(eta);
    invJ = inv(J);
    nu = invJ * eta_dot;
    
    Jdot = jacobian_Jdot(eta, eta_dot);
    [~, nu_dot] = auv_dynamics(eta, nu, tau_act, tau_dist);
    
    % \ddot{\eta} = \dot{J} \nu + J \dot{\nu}
    eta_ddot = Jdot * nu + J * nu_dot;
end
