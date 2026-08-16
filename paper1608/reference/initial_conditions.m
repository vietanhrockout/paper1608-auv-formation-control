function [eta_init, nu_init] = initial_conditions()
    % INITIAL_CONDITIONS Initial states for Leader (AUV0), Follower 1 (AUV1), Follower 2 (AUV2)
    % Paper Eq. (56):
    %   \eta_0(0) = [6, 6, 6, 0, 0, 0]^T
    %   \eta_1(0) = [1, 1, 4, 0, 0, 0]^T
    %   \eta_2(0) = [0, 2, 2, 0, 0, 0]^T
    % Initial velocities: assumed 0 (not explicitly specified in paper).
    
    eta_init = zeros(6, 3);
    eta_init(:, 1) = [6; 6; 6; 0; 0; 0];
    eta_init(:, 2) = [1; 1; 4; 0; 0; 0];
    eta_init(:, 3) = [0; 2; 2; 0; 0; 0];
    
    nu_init = zeros(6, 3);
end
