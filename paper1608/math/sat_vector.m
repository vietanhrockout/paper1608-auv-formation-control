function [tau_act, delta_tau] = sat_vector(tau_cmd, tau_min, tau_max)
    % SAT_VECTOR Bounds control input vector \tau_cmd within [\tau_min, \tau_max]
    % Returns:
    %   tau_act: Bounded physical control force/torque applied to AUV
    %   delta_tau: Actuator saturation deviation \tau_act - \tau_cmd (Issue E verified identity)
    
    if nargin < 2 || isempty(tau_min)
        tau_min = -[150; 150; 150; 30; 30; 30]; % Default nominal thrust/moment limits
    end
    if nargin < 3 || isempty(tau_max)
        tau_max = [150; 150; 150; 30; 30; 30];
    end
    
    tau_act = min(max(tau_cmd, tau_min), tau_max);
    delta_tau = tau_act - tau_cmd;
end
