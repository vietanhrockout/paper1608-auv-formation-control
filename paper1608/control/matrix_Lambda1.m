function Lambda1 = matrix_Lambda1(vel_err, params)
    % MATRIX_LAMBDA1 Computes diagonal matrix \Lambda_1(\upsilon_i) = diag{ |\upsilon_{ij}|^{\alpha_1 - 1} }
    % Eq. (24)
    
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    p = params.alpha1 - 1; % 1.2 - 1 = 0.2
    
    lambda_diag = zeros(6, 1);
    for j = 1:6
        lambda_diag(j) = abs(vel_err(j)) ^ p;
    end
    
    Lambda1 = diag(lambda_diag);
end
