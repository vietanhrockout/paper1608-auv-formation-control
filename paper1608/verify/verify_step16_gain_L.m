function verify_step16_gain_L()
    % VERIFY_STEP16_GAIN_L Tests dimension 6x6, non-negativity, and diagonal structure of L(\chi)
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'control'));
    
    chi_test = [1; -2; 0.5; -0.1; 0.05; -0.01];
    L = gain_matrix_L(chi_test);
    
    if ~isequal(size(L), [6, 6])
        error('STEP 16: FAIL - L matrix dimension must be 6x6');
    end
    if any(diag(L) < 0)
        error('STEP 16: FAIL - L matrix diagonal elements must be non-negative');
    end
    if norm(L - diag(diag(L))) > 1e-12
        error('STEP 16: FAIL - L matrix is not strictly diagonal');
    end
    
    fprintf('STEP 16: PASS\n');
end
