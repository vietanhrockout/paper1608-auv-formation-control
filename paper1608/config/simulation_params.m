function params = simulation_params()
    % SIMULATION_PARAMS Loads parameters for simulation with eq29_consistent reaching gains
    % Paper 1608 Eq. (29) derivation yields positive reaching gains (\sigma_1 \approx 2.8352, \sigma_2 \approx 5.2907).
    
    params = paper_params();
    params.sigma_mode = 'eq29_consistent';
    params = derived_params(params);
end
