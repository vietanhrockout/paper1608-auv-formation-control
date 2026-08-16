function verify_step05_derived_params()
    % VERIFY_STEP05_DERIVED_PARAMS Equation-fidelity verification of Step 5 parameters
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    
    % 1. Test paper_literal mode
    params = paper_params();
    params.sigma_mode = 'paper_literal';
    params = derived_params(params);

    tol = 1e-10;

    assert(abs(params.alpha2 - 0.00555555555555556) < tol, 'alpha2 mismatch');
    assert(abs(params.alpha3 - 0.416666666666667) < tol, 'alpha3 mismatch');

    assert(abs(params.a1 - 1.192474234254379) < 1e-10, 'a1 mismatch from PDF Eq. 22');
    assert(abs(params.a2 - 12.878721729947296) < 1e-10, 'a2 mismatch from PDF Eq. 22');

    assert(abs(params.sigma1_literal - 0.454545454545455) < 1e-10, 'sigma1 mismatch from PDF Eq. 26');

    % Expected inconsistency from literal Eq. (26)
    assert(params.sigma2_literal < 0, 'Expected negative sigma2_literal from PDF Eq. 26');

    % 2. Test sign_flip_candidate mode
    params_flip = paper_params();
    params_flip.sigma_mode = 'sign_flip_candidate';
    params_flip = derived_params(params_flip);
    assert(abs(params_flip.sigma2 - 2.222222222222222) < 1e-10, 'sign_flip_candidate mismatch');

    % 3. Test eq29_consistent mode (independent derivation from Eq. 29)
    params_eq29 = paper_params();
    params_eq29.sigma_mode = 'eq29_consistent';
    params_eq29 = derived_params(params_eq29);
    assert(abs(params_eq29.sigma1 - 2.835189689408660) < 1e-6, 'sigma1_eq29 mismatch');
    assert(abs(params_eq29.sigma2 - 5.290650904323204) < 1e-6, 'sigma2_eq29 mismatch');

    fprintf('STEP 05: PASS - PDF fidelity verified. Independent Eq. (29) derivation verified (sigma1=2.8352, sigma2=5.2907).\n');
end
