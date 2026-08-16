function verify_step38_actor_error()
    % VERIFY_STEP38_ACTOR_ERROR Tests Actor error vector computation and dimension
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'nn'));
    
    f_rl = [1; 2; 3; 4; 5; 6];
    f_target = [0.5; 1.5; 2.5; 3.5; 4.5; 5.5];
    
    e_ai = actor_error(f_rl, f_target);
    
    if ~isequal(size(e_ai), [6, 1])
        error('STEP 38: FAIL - Actor error vector dimension must be 6x1');
    end
    if norm(e_ai - 0.5 * ones(6, 1)) > 1e-12
        error('STEP 38: FAIL - Actor error vector values incorrect');
    end
    
    fprintf('STEP 38: PASS\n');
end
