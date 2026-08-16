function tau_d = ocean_disturbance(t, i_auv, omega)
    % OCEAN_DISTURBANCE External ocean current disturbance for i-th AUV (Eq. 55)
    % \tau_d1 = \tau_d2 = \tau_d3 = \sin(omega * i * t)
    % \tau_d4 = \tau_d5 = \tau_d6 = \cos(omega * i * t)
    
    if nargin < 2 || isempty(i_auv)
        i_auv = 1;
    end
    if nargin < 3 || isempty(omega)
        omega = 0.01; % Configurable frequency assumption
    end
    
    val_sin = sin(omega * i_auv * t);
    val_cos = cos(omega * i_auv * t);
    
    tau_d = [
        val_sin;
        val_sin;
        val_sin;
        val_cos;
        val_cos;
        val_cos
    ];
end
