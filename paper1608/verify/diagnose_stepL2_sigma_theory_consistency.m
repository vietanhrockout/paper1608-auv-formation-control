function diagnose_stepL2_sigma_theory_consistency()
% DIAGNOSE_STEPL2_SIGMA_THEORY_CONSISTENCY
%
% Issue L / Step L.2
%
% Pure algebraic/theoretical audit of:
%   Paper Eq. (26) vs Paper Eq. (29) vs desired predefined time T1*.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));

    p0 = paper_params();

    z  = p0.zeta1;
    z2 = p0.zeta2;
    z3 = p0.zeta3;

    eps0  = p0.eps0;
    Tstar = p0.T1star;

    out_file = fullfile(fileparts(project_root), 'l2_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    rho1 = (1 + z*z2) / (2*z);
    rho2 = (1 + z*z3) / (2*z);

    crho1 = z*rho1;
    crho2 = z*rho2;

    p('\n');
    p('============================================================\n');
    p(' STEP L.2 -- SIGMA THEORY CONSISTENCY AUDIT\n');
    p('============================================================\n');

    p('zeta1      = %.12f\n', z);
    p('rho1       = %.12f\n', rho1);
    p('rho2       = %.12f\n', rho2);
    p('zeta1*rho1 = %.12f\n', crho1);
    p('zeta1*rho2 = %.12f\n', crho2);

    assert(crho1 < 1, 'L.2 FAIL: low-order exponent condition violated.');
    assert(crho2 > 1, 'L.2 FAIL: high-order exponent condition violated.');

    gamma1_required = (1 / (eps0*Tstar*(1-crho1)))^(1/z);
    gamma2_required = (1 / ((1-eps0)*Tstar*(crho2-1)))^(1/z);

    scale1 = 6^((1-z)/z) * 2^rho1;
    scale2 = 6^((1-z)/z) * 2^rho2;

    sigma1_required = gamma1_required / scale1;
    sigma2_required = gamma2_required / scale2;

    p('\nREQUIRED BY EQ. (29) FOR T*=%.6f s\n', Tstar);
    p('gamma1_required = %.12e\n', gamma1_required);
    p('gamma2_required = %.12e\n', gamma2_required);
    p('sigma1_required = %.12e\n', sigma1_required);
    p('sigma2_required = %.12e\n', sigma2_required);

    modes = { ...
        'paper_literal', ...
        'sign_flip_candidate', ...
        'eq29_consistent'};

    p('\n');
    p('============================================================\n');
    p(' BRANCH AUDIT\n');
    p('============================================================\n');

    for m = 1:numel(modes)

        params = paper_params();
        params.sigma_mode = modes{m};
        params = derived_params(params);

        sigma1 = params.sigma1;
        sigma2 = params.sigma2;

        gamma1 = scale1 * sigma1;
        gamma2 = scale2 * sigma2;

        valid_positive = (gamma1 > 0) && (gamma2 > 0);

        if gamma1 > 0
            Tlow = 1 / (gamma1^z * (1-crho1));
        else
            Tlow = NaN;
        end

        if gamma2 > 0
            Thigh = 1 / (gamma2^z * (crho2-1));
        else
            Thigh = NaN;
        end

        if valid_positive
            Ttotal = Tlow + Thigh;
        else
            Ttotal = NaN;
        end

        s_pos = logspace(-8, 5, 2000).';
        s_grid = [-flipud(s_pos); s_pos];
        q_grid = pt_reaching_term(s_grid, params);

        alignment = s_grid .* q_grid;
        min_alignment = min(alignment);
        n_bad = sum(alignment <= 0);
        frac_bad = n_bad / numel(alignment);

        s_cross = NaN;
        if sigma1 > 0 && sigma2 < 0 && z3 > z2
            s_cross = (sigma1 / abs(sigma2)) ^ (1 / (z3-z2));
        end

        p('\n------------------------------------------------------------\n');
        p('MODE: %s\n', modes{m});
        p('------------------------------------------------------------\n');

        p('sigma1 = %.12e\n', sigma1);
        p('sigma2 = %.12e\n', sigma2);
        p('gamma1_eff = %.12e\n', gamma1);
        p('gamma2_eff = %.12e\n', gamma2);
        p('positive effective coefficients = %d\n', valid_positive);
        p('T_low  = %.12e s\n', Tlow);
        p('T_high = %.12e s\n', Thigh);
        p('T_total= %.12e s\n', Ttotal);
        p('min s*q(s) over grid = %.12e\n', min_alignment);
        p('bad sign samples      = %d / %d\n', n_bad, numel(alignment));
        p('bad sign fraction     = %.12e\n', frac_bad);
        p('analytic s_cross      = %.12e\n', s_cross);

        switch modes{m}
            case 'paper_literal'
                assert(sigma2 < 0, 'L.2 FAIL: expected literal Eq.26 sigma2 to be negative.');
                assert(n_bad > 0, 'L.2 FAIL: expected literal branch to lose reaching sign alignment.');
            case 'sign_flip_candidate'
                assert(valid_positive, 'L.2 FAIL: sign-flip branch must be positive.');
                assert(n_bad == 0, 'L.2 FAIL: sign-flip branch should preserve reaching direction.');
            case 'eq29_consistent'
                assert(valid_positive, 'L.2 FAIL: Eq29 branch must be positive.');
                assert(n_bad == 0, 'L.2 FAIL: Eq29 branch should preserve reaching direction.');
                assert(abs(Ttotal - Tstar) < 1e-6, 'L.2 FAIL: Eq29 branch does not reconstruct T*.');
                assert(abs(sigma1-sigma1_required) < 1e-6 && abs(sigma2-sigma2_required) < 1e-6, ...
                    'L.2 FAIL: Eq29 sigma values disagree.');
        end
    end

    p('\n');
    p('============================================================\n');
    p(' EQ. (26) STRUCTURAL CHECK\n');
    p('============================================================\n');

    sigma1_eq26_direct = 1 / ((1-rho1)*eps0*Tstar);
    sigma2_eq26_direct = 1 / ((rho2-1)*(1-eps0)*Tstar);

    p('1/[(1-rho1) eps0 T*]       = %.12e\n', sigma1_eq26_direct);
    p('1/[(rho2-1)(1-eps0) T*]    = %.12e\n', sigma2_eq26_direct);

    p('\nNOTE: rho2 = %.6f < 1, hence the second literal Eq.(26) coefficient is necessarily negative.\n', rho2);
    p('But Eq.(29) reaches the large-state exponent condition through zeta1*rho2 = %.6f > 1.\n', crho2);

    p('\n============================================================\n');
    p(' STEP L.2 COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end
