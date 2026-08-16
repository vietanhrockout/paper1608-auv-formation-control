function L = gain_matrix_L(chi, params)
    % GAIN_MATRIX_L Computes diagonal gain matrix L(\chi_i) = diag{ l_{\chi ij} }
    % l_{\chi ij} = (a_1 |\chi_{ij}|^{\alpha_2} + a_2 |\chi_{ij}|^{\alpha_3})^{c\alpha_1}
    
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    a1 = params.a1;
    a2 = params.a2;
    alpha2 = params.alpha2;
    alpha3 = params.alpha3;
    c_alpha1 = params.c * params.alpha1;
    
    l_diag = zeros(6, 1);
    for j = 1:6
        abs_chi = abs(chi(j));
        base = a1 * (abs_chi ^ alpha2) + a2 * (abs_chi ^ alpha3);
        l_diag(j) = base ^ c_alpha1;
    end
    
    L = diag(l_diag);
end
