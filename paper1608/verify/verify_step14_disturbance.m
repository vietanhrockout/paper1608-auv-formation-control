function verify_step14_disturbance()
    % VERIFY_STEP14_DISTURBANCE Tests disturbance bounded magnitude <= 1 and dimension 6x1
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    
    t_sweep = linspace(0, 100, 200);
    
    for i_auv = 1:3
        for t = t_sweep
            tau_d = ocean_disturbance(t, i_auv);
            
            if ~isequal(size(tau_d), [6, 1])
                error('STEP 14: FAIL - Disturbance vector dimension must be 6x1');
            end
            if max(abs(tau_d)) > 1.0 + 1e-12
                error('STEP 14: FAIL - Disturbance magnitude exceeded 1.0 bound');
            end
        end
    end
    
    fprintf('STEP 14: PASS\n');
end
