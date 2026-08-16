function verify_step15_formation_error()
    % VERIFY_STEP15_FORMATION_ERROR Tests tracking error at exact desired formation position
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'reference'));
    
    t_test = 2.0;
    offsets = formation_offsets();
    [eta_d0, eta_d0_dot, ~] = reference_1608(t_test);
    
    for i_auv = 1:3
        % Set artificial state exactly at desired trajectory + offset
        eta_exact = eta_d0 + offsets(:, i_auv);
        eta_dot_exact = eta_d0_dot;
        
        [chi, vel_err] = formation_error(eta_exact, eta_dot_exact, t_test, i_auv);
        
        if norm(chi) > 1e-12
            error('STEP 15: FAIL - Position tracking error chi is not zero at exact formation state');
        end
        if norm(vel_err) > 1e-12
            error('STEP 15: FAIL - Velocity tracking error vel_err is not zero at exact formation state');
        end
    end
    
    fprintf('STEP 15: PASS\n');
end
