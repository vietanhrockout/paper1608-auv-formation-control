function verify_step28_rbf()
    % VERIFY_STEP28_RBF Tests RBF output bounds 0 < theta <= 1 and exact activation at center
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'math'));
    
    centers = [0, 1, -1; 0, 2, -2]; % 2D input, 3 nodes
    width = 5.0;
    
    % Test at exact center of node 1: [0, 0]^T
    theta_center = rbf_gaussian([0; 0], centers, width);
    if abs(theta_center(1) - 1.0) > 1e-12
        error('STEP 28: FAIL - RBF activation at exact node center must equal 1.0');
    end
    
    % Test arbitrary input
    theta_arb = rbf_gaussian([0.5; 0.5], centers, width);
    if any(theta_arb <= 0) || any(theta_arb > 1.0)
        error('STEP 28: FAIL - RBF activations must be strictly in range (0, 1]');
    end
    
    fprintf('STEP 28: PASS\n');
end
