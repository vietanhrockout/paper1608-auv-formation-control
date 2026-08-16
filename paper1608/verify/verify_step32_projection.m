function verify_step32_projection()
    % VERIFY_STEP32_PROJECTION Tests projection operator equation fidelity & boundary invariance
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'nn'));
    
    delta = 10.0;
    
    % Test 1: Interior unprojected update fidelity (wdot == v, exact equality, no double negative!)
    w_int = [1; 2; -1; 0.5; 0];
    v_test = [-0.5; 1.2; 0.3; -0.8; 0.4];
    wdot_int = projection_operator(w_int, v_test, delta);
    
    if norm(wdot_int - v_test) > 1e-12
        error('STEP 32: FAIL - Projection operator altered update in the interior (wdot != v)');
    end
    
    % Test 2: Boundary projection orthogonality (w' * wdot == 0 when norm(w) = delta and w'*v > 0)
    w_bnd = [6; 8; 0; 0; 0]; % norm(w_bnd) = 10 == delta
    v_outward = [1; 1; 0; 0; 0]; % w'*v = 14 > 0
    wdot_bnd = projection_operator(w_bnd, v_outward, delta);
    
    if abs(w_bnd' * wdot_bnd) > 1e-12
        error('STEP 32: FAIL - Boundary projection derivative is not tangential to the boundary (w'' * wdot != 0)');
    end
    
    % Test 3: Continuous-time invariant d/dt(||w||^2) <= 0 when ||w|| >= delta and w'*v > 0
    w_over = [6.1; 8.1; 0; 0; 0]; % norm(w_over) = 10.14 > delta
    wdot_over = projection_operator(w_over, v_outward, delta);
    
    if abs(w_over' * wdot_over) > 1e-12
        error('STEP 32: FAIL - Projection operator failed radial cancellation when norm(w) >= delta');
    end
    
    fprintf('STEP 32: PASS\n');
end
