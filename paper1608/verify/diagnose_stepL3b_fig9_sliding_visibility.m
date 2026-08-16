function diagnose_stepL3b_fig9_sliding_visibility()
% DIAGNOSE_STEPL3B_FIG9_SLIDING_VISIBILITY
%
% Purpose:
%   Audit whether Fig. 9's small y-axis necessarily implies that the
%   simulated sliding surface had O(10) initial magnitude.
%
% Important:
%   This is NOT an AUV simulation.
%   This is NOT a controller repair.
%   This is NOT figure fitting.
%
% It evaluates:
%   1) literal Eq. (21) s(0);
%   2) clipping ratio relative to published Fig. 9 y-axis;
%   3) ideal q-only time required to enter the visible window.
%
% NO production parameter modification.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'math'));

    %% ============================================================
    % 1. Initial physical state
    % =============================================================

    t0 = 0;

    [eta_init, nu_init] = initial_conditions();
    offsets = formation_offsets();

    [eta_d, eta_d_dot, ~] = reference_1608(t0);

    eta_dot = zeros(6,3);

    for i = 1:3
        J = jacobian_J(eta_init(:,i));
        eta_dot(:,i) = J * nu_init(:,i);
    end

    out_file = fullfile(fileparts(project_root), 'l3b_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    %% ============================================================
    % 2. Candidate-B leader-relative formation architecture
    %    established in L.3a as Fig. 7/8 consistent
    % =============================================================

    chi = zeros(6,3);
    vel_err = zeros(6,3);

    % Leader tracks virtual desired reference
    chi(:,1) = eta_init(:,1) - eta_d;
    vel_err(:,1) = eta_dot(:,1) - eta_d_dot;

    % Followers track actual leader
    for i = 2:3
        chi(:,i) = ...
            eta_init(:,i) ...
            - eta_init(:,1) ...
            - offsets(:,i);

        vel_err(:,i) = ...
            eta_dot(:,i) ...
            - eta_dot(:,1);
    end

    %% ============================================================
    % 3. Literal Eq. (21)
    % =============================================================

    p0 = paper_params();
    p0 = derived_params(p0);

    s_literal = zeros(6,3);

    for i = 1:3
        s_literal(:,i) = ...
            sliding_surface(chi(:,i), vel_err(:,i), p0);
    end

    %% ============================================================
    % 4. Diagnostic-only alternative:
    %    L = I surface
    %
    % NOT claiming this was used by authors.
    % Only included because its scale visually resembles Fig. 9.
    % =============================================================

    s_identity = zeros(6,3);

    for i = 1:3
        s_identity(:,i) = ...
            chi(:,i) ...
            + sigpow(vel_err(:,i), p0.alpha1);
    end

    %% ============================================================
    % 5. Published Fig. 9 approximate visible y windows
    %
    % These are visual plot limits, NOT measured simulation data.
    % =============================================================

    ylim_low  = [  0; -10; -15 ];
    ylim_high = [ 15;   2;   5 ];

    visible_threshold = [15; 10; 15];

    %% ============================================================
    % 6. Print literal surface scale
    % =============================================================

    p('\n');
    p('============================================================\n');
    p(' STEP L.3b -- FIG. 9 SLIDING-SCALE VISIBILITY AUDIT\n');
    p('============================================================\n');

    p('\nLeader-relative formation errors from L.3a:\n');

    for i = 1:3
        p('AUV%d chi_xyz = % .12f  % .12f  % .12f\n', i-1, chi(1:3,i));
        p('AUV%d vel_xyz = % .12f  % .12f  % .12f\n', i-1, vel_err(1:3,i));
    end

    p('\n------------------------------------------------------------\n');
    p('LITERAL PDF EQ. (21) INITIAL s\n');
    p('------------------------------------------------------------\n');

    for i = 1:3
        p('AUV%d s_xyz = % .12e  % .12e  % .12e\n', i-1, s_literal(1:3,i));
        p('AUV%d ||s||_inf = %.12e\n', i-1, norm(s_literal(:,i), inf));

        ratio = norm(s_literal(1:3,i), inf) / visible_threshold(i);

        p('AUV%d clipping-scale ratio = %.12e\n', i-1, ratio);
    end

    %% ============================================================
    % 7. L = I diagnostic candidate
    % =============================================================

    p('\n------------------------------------------------------------\n');
    p('DIAGNOSTIC ONLY: L = I SURFACE\n');
    p('s_I = chi + sig^{alpha1}(vel_err)\n');
    p('------------------------------------------------------------\n');

    for i = 1:3
        p('AUV%d s_I_xyz = % .12e  % .12e  % .12e\n', i-1, s_identity(1:3,i));
    end

    %% ============================================================
    % 8. Exact oracles for literal Eq. (21)
    % =============================================================

    expected_s = [ ...
         7.4190190857e2,  -1.1676628772e3, -2.2152083699e3;
         7.4202810004e2,  -1.4061784252e3, -5.5687297167e2;
         3.4920473442e3,  -3.9213347345e2, -1.1676628772e3];

    assert(norm(s_literal(1:3,:) - expected_s, inf) < 1e-6, ...
        'L.3b FAIL: s_literal oracle mismatch.');

    %% ============================================================
    % 9. q-only visibility-time audit
    % =============================================================

    modes = { ...
        'paper_literal', ...
        'sign_flip_candidate', ...
        'eq29_consistent'};

    p('\n============================================================\n');
    p(' IDEAL q-ONLY TIME TO ENTER FIG. 9 VISIBLE WINDOW\n');
    p('============================================================\n');

    for imode = 1:numel(modes)

        mode = modes{imode};

        params = paper_params();
        params.sigma_mode = mode;
        params = derived_params(params);

        p('\n------------------------------------------------------------\n');
        p('MODE: %s\n', mode);
        p('sigma1 = %.12e\n', params.sigma1);
        p('sigma2 = %.12e\n', params.sigma2);
        p('------------------------------------------------------------\n');

        for i = 1:3

            t_vis = NaN(3,1);

            for j = 1:3

                s0 = abs(s_literal(j,i));
                Svis = visible_threshold(i);

                if s0 <= Svis
                    t_vis(j) = 0;
                    continue;
                end

                q0 = pt_reaching_term(s_literal(j,i), params);

                if s_literal(j,i) * q0 <= 0
                    t_vis(j) = NaN;
                    continue;
                end

                q_abs = @(xi) ...
                    abs( ...
                        params.sigma1 .* xi.^params.zeta2 ...
                      + params.sigma2 .* xi.^params.zeta3 ...
                    ).^params.zeta1;

                xcheck = logspace( ...
                    log10(Svis), ...
                    log10(s0), ...
                    500);

                inner_check = ...
                    params.sigma1 .* xcheck.^params.zeta2 ...
                  + params.sigma2 .* xcheck.^params.zeta3;

                if any(inner_check <= 0)
                    t_vis(j) = NaN;
                    continue;
                end

                t_vis(j) = integral( ...
                    @(xi) 1 ./ q_abs(xi), ...
                    Svis, s0, ...
                    'RelTol', 1e-10, ...
                    'AbsTol', 1e-12);
            end

            p('AUV%d T_visible xyz [s] = ', i-1);

            for j = 1:3
                if isnan(t_vis(j))
                    p('NaN  ');
                else
                    p('%.12e  ', t_vis(j));
                end
            end

            p('\n');

            finite_t = t_vis(isfinite(t_vis));

            if isempty(finite_t)
                p('AUV%d max finite T_visible = INVALID\n', i-1);
            else
                p('AUV%d max T_visible = %.12e s\n', i-1, max(finite_t));
                p('AUV%d fraction of 100-s plot width = %.12e %%\n', ...
                    i-1, 100 * max(finite_t) / 100);
            end
        end
    end

    %% ============================================================
    % 10. Interpretation
    % =============================================================

    p('\n============================================================\n');
    p(' INTERPRETATION RULE\n');
    p('============================================================\n');

    p(['A small Fig. 9 y-axis is NOT sufficient evidence that\n' ...
       'the underlying initial s was O(10). MATLAB axis clipping\n' ...
       'can hide an O(1e3) initial transient.\n\n']);

    p(['If eq29_consistent reaches the visible window in O(1e-2) s,\n' ...
       'then Fig. 9 cannot resolve the true initial sliding magnitude\n' ...
       'on a 0--100 s horizontal axis.\n']);

    p('\n============================================================\n');
    p(' STEP L.3b COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end
