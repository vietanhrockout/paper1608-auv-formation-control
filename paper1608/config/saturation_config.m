function sat_cfg = saturation_config()
    % SATURATION_CONFIG Configurable physical actuator force & moment limits
    
    sat_cfg = struct();
    sat_cfg.force_max  = 150; % Maximum thrust force (N)
    sat_cfg.force_min  = -150;
    sat_cfg.moment_max = 30;  % Maximum torque moment (N*m)
    sat_cfg.moment_min = -30;
    
    sat_cfg.tau_max = [sat_cfg.force_max; sat_cfg.force_max; sat_cfg.force_max; ...
                       sat_cfg.moment_max; sat_cfg.moment_max; sat_cfg.moment_max];
                   
    sat_cfg.tau_min = [sat_cfg.force_min; sat_cfg.force_min; sat_cfg.force_min; ...
                       sat_cfg.moment_min; sat_cfg.moment_min; sat_cfg.moment_min];
end
