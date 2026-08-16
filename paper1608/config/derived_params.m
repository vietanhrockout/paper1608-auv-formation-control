function params = derived_params(params)
%DERIVED_PARAMS Derived parameters from Paper 1608.
%
% IMPORTANT:
%   - Eq. (22) is implemented literally from the PDF:
%     a1 = 6^(c-1) / ((1 - b1) * eps0 * T2star)
%     a2 = 6^(c-1) / ((b2 - 1) * (1 - eps0) * T2star)
%   - Eq. (26) PDF literal yields negative sigma2 (-2.222222).
%   - 'sign_flip_candidate' flips sign to +2.222222 for empirical testing.
%   - 'eq29_consistent' implements the line-by-line independent derivation from Eq. (29) & Lemma 1:
%     sigma1 = sqrt(15) / 2^(rho1) approx 2.835190
%     sigma2 = sqrt(60) / 2^(rho2) approx 5.290651

    if nargin < 1 || isempty(params)
        params = paper_params();
    end

    %% Eq. (21): intermediate exponents
    params.alpha2 = params.b1 ...
                  - 1/(params.c*params.alpha1);

    params.alpha3 = params.b2 ...
                  - 1/(params.c*params.alpha1);

    %% Eq. (22): predefined-time sliding gains (literal PDF)
    params.a1 = 6^(params.c - 1) / ...
        ((1 - params.b1) * ...
         params.eps0 * ...
         params.T2star);

    params.a2 = 6^(params.c - 1) / ...
        ((params.b2 - 1) * ...
         (1 - params.eps0) * ...
         params.T2star);

    %% Eq. (26): reaching gains
    z1 = params.zeta1;
    z2 = params.zeta2;
    z3 = params.zeta3;

    % Literal PDF Eq. (26)
    params.sigma1_literal = ...
        (2*z1) / ...
        ((2*z1 - 1 - z1*z2) * ...
         params.eps0 * params.T1star);

    params.sigma2_literal = ...
        (2*z1) / ...
        ((1 + z1*z3 - 2*z1) * ...
         (1 - params.eps0) * params.T1star);

    % Independent Eq. (29) self-consistent derivation
    rho1 = (1 + z1*z2) / (2*z1); % 0.45
    rho2 = (1 + z1*z3) / (2*z1); % 0.55
    c_rho1 = z1 * rho1;          % 0.9
    c_rho2 = z1 * rho2;          % 1.1

    gamma1 = (1 / (params.eps0 * params.T1star * (1 - c_rho1)))^(1/z1);        % sqrt(2.5)
    gamma2 = (1 / ((1 - params.eps0) * params.T1star * (c_rho2 - 1)))^(1/z1);  % sqrt(10)

    params.sigma1_eq29 = (sqrt(6) * gamma1) / (2^rho1); % approx 2.8351897
    params.sigma2_eq29 = (sqrt(6) * gamma2) / (2^rho2); % approx 5.2906509

    switch params.sigma_mode

        case 'paper_literal'
            params.sigma1 = params.sigma1_literal;
            params.sigma2 = params.sigma2_literal;

        case 'sign_flip_candidate'
            params.sigma1 = params.sigma1_literal;
            params.sigma2 = -params.sigma2_literal;

        case 'eq29_consistent'
            params.sigma1 = params.sigma1_eq29;
            params.sigma2 = params.sigma2_eq29;

        case 'derived_corrected'
            error(['Eq. (26) is still theoretically unresolved in PDF text. ' ...
                   'Use sigma_mode = ''eq29_consistent'' for the independent ' ...
                   'Eq. (29) self-consistent derivation (sigma1=2.8352, sigma2=5.2907).']);

        otherwise
            error('Unknown sigma_mode.');
    end
end
