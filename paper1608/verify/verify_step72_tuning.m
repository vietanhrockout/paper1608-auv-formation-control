function verify_step72_tuning()
    % VERIFY_STEP72_TUNING Verifies derived gain/exponent sign structure.
    %
    % REWRITTEN during the post-R11 full-project audit. The previous
    % version loaded paper_params() + derived_params() and asserted that
    % a1, a2, sigma1, sigma2 are ALL strictly positive. That assertion is
    % wrong for the configuration it was loading: paper_params() defaults
    % to sigma_mode='paper_literal', and the literal Eq.(26) reading is
    % KNOWN and DOCUMENTED to yield sigma2 = -2.222222 (Issue C) -- that
    % negative value is the entire reason the 'eq29_consistent' branch
    % exists. So the oracle asserted the negation of a documented project
    % finding and would fail on a correct codebase. It had gone unnoticed
    % because it was absent from the subset runner and the full sweep
    % never reached it (Issue K).
    %
    % What is checked now, split by configuration:
    %   1. PRODUCTION config (simulation_params -> eq29_consistent): every
    %      gain and exponent used by the actual simulation is strictly
    %      positive. This is the property that genuinely matters.
    %   2. PAPER-LITERAL config: sigma2 IS strictly negative -- asserted
    %      explicitly, so Issue C is pinned down by a test instead of only
    %      living in prose. If a future edit silently "fixed" the literal
    %      branch into positivity, that would be a reproduction-fidelity
    %      regression and this oracle now catches it.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));

    % --- 1. Production configuration must be entirely positive ---
    sim = simulation_params();
    assert(strcmp(sim.sigma_mode, 'eq29_consistent'), ...
        'STEP 72: FAIL - simulation_params no longer uses eq29_consistent (got %s)', sim.sigma_mode);

    checks = {'a1', 'a2', 'sigma1', 'sigma2', 'alpha2', 'alpha3'};
    for k = 1:numel(checks)
        v = sim.(checks{k});
        assert(isscalar(v) && isfinite(v) && v > 0, ...
            'STEP 72: FAIL - production %s must be finite and strictly positive (got %g)', checks{k}, v);
    end

    % --- 2. Paper-literal branch must still exhibit Issue C ---
    lit = paper_params();
    lit.sigma_mode = 'paper_literal';
    lit = derived_params(lit);
    assert(lit.sigma1 > 0, ...
        'STEP 72: FAIL - paper-literal sigma1 expected positive (got %g)', lit.sigma1);
    assert(lit.sigma2 < 0, ...
        ['STEP 72: FAIL - paper-literal sigma2 expected NEGATIVE per Issue C (got %g). ' ...
         'If Eq.(26) literal now yields a positive sigma2, the literal-reading branch has ' ...
         'been altered and the Issue C finding needs re-auditing.'], lit.sigma2);

    fprintf(['STEP 72: PASS (production eq29_consistent all-positive: sigma1=%.6f sigma2=%.6f; ' ...
        'paper_literal retains Issue C sigma2=%.6f)\n'], sim.sigma1, sim.sigma2, lit.sigma2);
end
