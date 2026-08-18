function diagnose_stepK7_coarse_projected_rk4(t_span, h)
% DIAGNOSE_STEPK7_COARSE_PROJECTED_RK4
%
% Step K.7: Since BOTH ode45 (explicit, non-stiff) and ode15s (implicit,
% stiff-capable) genuinely stall at the critic-weight projection boundary
% (Step K.5/K.6 findings: the vector field has a non-smooth kink exactly
% where the trajectory sits once Wc is pinned at delta_c, which defeats
% both adaptive step-size control AND Newton-iteration-based implicit
% solvers), the only reliable approach is the purpose-built projected
% fixed-step integrator (Step K.4/K.5's projected_rk4_integrate.m).
%
% The blocker there was throughput: h=1e-6 gives ~100-125 steps/s, far
% too slow for 15-100s horizons. This script tests whether a MUCH
% coarser fixed step (e.g. h=1e-4, 100x coarser) still produces a
% stable, bounded trajectory once starting from the post-saturation
% checkpoint (k5_hotphase_checkpoint.mat, Wc already pinned at delta_c
% for all 3 AUVs) -- the projection retraction is exact and O(1) per
% step regardless of h, so the only risk is losing accuracy in the
% smooth physical states (eta, nu, omega, Wa), not violating any bound.
%
% NO controller/model modification.

    if nargin < 1 || isempty(t_span)
        t_span = 1.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    paths = project_paths();
    ck = load(fullfile(paths.diagnostics, 'k5_hotphase_checkpoint.mat'));

    fprintf('\n============================================================\n');
    fprintf(' STEP K.7 -- COARSE FIXED-STEP PROJECTED RK4 (from checkpoint)\n');
    fprintf('============================================================\n');
    fprintf('starting at t=0.15s (checkpoint), extending %.4fs at h=%.2e (%d steps)\n', ...
        t_span, h, ceil(t_span/h));

    tic;
    [t_seg, X_seg, stats] = projected_rk4_integrate(t_span, h, ck.X_hot_end, ck.params, ck.sat_cfg, ck.cfg);
    elapsed = toc;

    fprintf('\nRESULT: steps=%d elapsed=%.3fs (%.1f steps/s) max_retraction=%.3e total_retracted=%d\n', ...
        stats.nsteps, stats.elapsed, stats.nsteps/max(stats.elapsed,1e-9), ...
        stats.max_retraction, stats.total_retracted);

    Xend = X_seg(end,:).';
    [eta_e, nu_e, ~, Wa_e, Wc_e] = unpack_states(Xend, ck.cfg);

    fprintf('\nEndpoint at t=%.4fs (0.15+%.4f):\n', 0.15+t_span, t_span);
    for i = 1:3
        fprintf('  AUV%d: eta=[%.4f %.4f %.4f]  ||nu||=%.4f  ||Wc||=%.6f  ||Wa||_F=%.6f\n', ...
            i-1, eta_e(1,i), eta_e(2,i), eta_e(3,i), norm(nu_e(:,i)), norm(Wc_e(:,i)), norm(Wa_e{i},'fro'));
    end

    assert(~any(isnan(Xend)) && ~any(isinf(Xend)), 'K.7 FAIL: NaN/Inf at endpoint.');
    for i = 1:3
        assert(norm(Wc_e(:,i)) <= ck.cfg.delta_c + 1e-6, 'K.7 FAIL: Wc exceeded delta_c.');
        for j = 1:6
            assert(norm(Wa_e{i}(:,j)) <= ck.cfg.delta_a + 1e-6, 'K.7 FAIL: Wa column exceeded delta_a.');
        end
    end
    fprintf('\nSTATUS: PASS -- finite, structural bounds held.\n');

    extrap_15s = stats.elapsed * (14.85/t_span);
    extrap_100s = stats.elapsed * (99.85/t_span);
    fprintf('\nExtrapolated wall time at this h for remaining 14.85s (Phase B.2 total 15s): %.1f s (%.1f min)\n', extrap_15s, extrap_15s/60);
    fprintf('Extrapolated wall time at this h for remaining 99.85s (Phase C total 100s):  %.1f s (%.1f min)\n', extrap_100s, extrap_100s/60);
end
