function Ltilde = gain_matrix_Ltilde(chi, params)
    % GAIN_MATRIX_LTILDE Computes derivative diagonal matrix \tilde{L}(\chi_i) = diag{ |\tilde{l}_{\chi ij}| }
    % Eq. (24): \tilde{l}_{\chi ij} = c\alpha_1 A^{c\alpha_1 - 1} (a_1\alpha_2 |\chi_{ij}|^{\alpha_2} + a_2\alpha_3 |\chi_{ij}|^{\alpha_3})
    % where A = a_1 |\chi_{ij}|^{\alpha_2} + a_2 |\chi_{ij}|^{\alpha_3}
    
    if nargin < 2 || isempty(params)
        params = paper_params();
        params = derived_params(params);
    end
    
    a1 = params.a1;
    a2 = params.a2;
    alpha2 = params.alpha2;
    alpha3 = params.alpha3;
    c_alpha1 = params.c * params.alpha1;
    
    ltilde_diag = zeros(6, 1);
    for j = 1:6
        abs_chi = abs(chi(j));
        if abs_chi == 0
            ltilde_val = 0;
        else
            A = a1 * (abs_chi ^ alpha2) + a2 * (abs_chi ^ alpha3);
            term2 = a1 * alpha2 * (abs_chi ^ alpha2) + a2 * alpha3 * (abs_chi ^ alpha3);
            ltilde_val = c_alpha1 * (A ^ (c_alpha1 - 1)) * term2;
        end
        ltilde_diag(j) = abs(ltilde_val);
    end
    
    Ltilde = diag(ltilde_diag);
end
