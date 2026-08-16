function diagnose_stepK3_projection_step_refinement()
% DIAGNOSE_STEPK3_PROJECTION_STEP_REFINEMENT
%
% Step K.3:
% Quantify whether Critic projection-bound violation converges toward zero
% under solver MaxStep refinement.
%
% IMPORTANT:
%   - No clipping
%   - No controller tuning
%   - No learning-rate tuning
%   - No projection modification
%   - Same closed-loop RHS
%   - Same RelTol / AbsTol
%
% Only MaxStep is varied locally in this diagnostic.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    params  = simulation_params();
    sat_cfg = saturation_config();
    cfg     = nn_config();

    delta_c = cfg.delta_c;

    %% ------------------------------------------------------------
    % Initial 549-state vector
    % -------------------------------------------------------------
    [eta_init, nu_init] = initial_conditions();

    omega_aw = zeros(6,3);

    Wa = { ...
        zeros(cfg.actor_n_nodes,6), ...
        zeros(cfg.actor_n_nodes,6), ...
        zeros(cfg.actor_n_nodes,6)};

    Wc = zeros(cfg.critic_n_nodes,3);

    X0 = pack_states( ...
        eta_init, ...
        nu_init, ...
        omega_aw, ...
        Wa, ...
        Wc, ...
        cfg);

    %% ------------------------------------------------------------
    % Horizon
    %
    % AUV0 first crossing in K.2 occurred around 6.88e-5 s.
    % 8e-5 s is enough to include all three first boundary crossings.
    % -------------------------------------------------------------
    t_micro = 8e-5;

    %% ------------------------------------------------------------
    % MaxStep refinement sequence
    %
    % First value reproduces current production cap.
    % Remaining values progressively constrain the numerical step.
    % -------------------------------------------------------------
    h_caps = [ ...
        5e-2, ...
        1e-6, ...
        2e-7, ...
        5e-8];

    nruns = numel(h_caps);

    maxW       = zeros(nruns,3);
    violation  = zeros(nruns,3);
    relViolation = zeros(nruns,3);

    nPoints       = zeros(nruns,1);
    minStepActual = NaN(nruns,1);
    maxStepActual = NaN(nruns,1);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.3 -- PROJECTION STEP-REFINEMENT AUDIT\n');
    fprintf('============================================================\n');

    fprintf('t_micro = %.6e s\n', t_micro);
    fprintf('delta_c = %.6e\n', delta_c);
    fprintf('RelTol  = 1e-3\n');
    fprintf('AbsTol  = 1e-4\n');

    for r = 1:nruns

        h_cap = h_caps(r);

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('RUN %d / %d\n', r, nruns);
        fprintf('MaxStep cap = %.6e s\n', h_cap);
        fprintf('------------------------------------------------------------\n');

        opts = odeset( ...
            'RelTol', 1e-3, ...
            'AbsTol', 1e-4, ...
            'MaxStep', h_cap, ...
            'Refine', 1);

        tic;

        [t, X] = ode45( ...
            @(tt,xx) rhs_3auv_rl( ...
                tt, xx, params, sat_cfg, cfg), ...
            [0 t_micro], ...
            X0, ...
            opts);

        elapsed = toc;

        nt = length(t);
        nPoints(r) = nt;

        if nt > 1

            h_actual = diff(t);

            minStepActual(r) = min(h_actual);
            maxStepActual(r) = max(h_actual);

        end

        %% --------------------------------------------------------
        % Extract raw Critic weights
        % ---------------------------------------------------------
        Wnorm = zeros(nt,3);

        for k = 1:nt

            Xk = X(k,:).';

            [~, ~, ~, ~, Wc_mat] = ...
                unpack_states(Xk, cfg);

            for i = 1:3
                Wnorm(k,i) = norm(Wc_mat(:,i));
            end

        end

        %% --------------------------------------------------------
        % Metrics
        % ---------------------------------------------------------
        for i = 1:3

            maxW(r,i) = max(Wnorm(:,i));

            violation(r,i) = max( ...
                0, ...
                maxW(r,i) - delta_c);

            relViolation(r,i) = ...
                violation(r,i) / delta_c;

        end

        fprintf('solver points       = %d\n', nt);

        if nt > 1
            fprintf('min actual step     = %.12e s\n', ...
                minStepActual(r));

            fprintf('max actual step     = %.12e s\n', ...
                maxStepActual(r));
        end

        fprintf('elapsed time        = %.3f s\n', elapsed);

        for i = 1:3

            fprintf('\nAUV %d\n', i-1);

            fprintf('max ||Wc||          = %.12e\n', ...
                maxW(r,i));

            fprintf('absolute violation  = %.12e\n', ...
                violation(r,i));

            fprintf('relative violation  = %.12e\n', ...
                relViolation(r,i));

        end
    end

    %% ------------------------------------------------------------
    % Summary table
    % -------------------------------------------------------------
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.3 SUMMARY\n');
    fprintf('============================================================\n');

    fprintf([ ...
        'MaxStep_cap     max_h_actual   ' ...
        'Wc0_max   err0   ' ...
        'Wc1_max   err1   ' ...
        'Wc2_max   err2\n']);

    for r = 1:nruns

        fprintf([ ...
            '%.3e   %.3e   ' ...
            '%.8f %.8f   ' ...
            '%.8f %.8f   ' ...
            '%.8f %.8f\n'], ...
            h_caps(r), ...
            maxStepActual(r), ...
            maxW(r,1), violation(r,1), ...
            maxW(r,2), violation(r,2), ...
            maxW(r,3), violation(r,3));

    end

    %% ------------------------------------------------------------
    % Trend diagnostics
    % -------------------------------------------------------------
    fprintf('\nREFINEMENT RATIOS:\n');

    for i = 1:3

        fprintf('\nAUV %d\n', i-1);

        for r = 2:nruns

            e_prev = violation(r-1,i);
            e_now  = violation(r,i);

            if e_prev > 0

                reduction = e_now / e_prev;

                fprintf( ...
                    'run %d -> %d: violation ratio = %.6e\n', ...
                    r-1, r, reduction);

            else

                fprintf( ...
                    'run %d -> %d: previous violation already zero\n', ...
                    r-1, r);

            end

        end

    end

    %% ------------------------------------------------------------
    % Automatic classification
    %
    % This is deliberately trend-based, not a hard physical PASS threshold.
    % -------------------------------------------------------------
    strong_refinement_evidence = true;

    for i = 1:3

        if violation(end,i) >= violation(1,i)
            strong_refinement_evidence = false;
        end

    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.3 CLASSIFICATION\n');
    fprintf('============================================================\n');

    if strong_refinement_evidence

        fprintf([ ...
            'RESULT: projection-bound violation decreases under ' ...
            'step refinement.\n']);

        fprintf([ ...
            'This supports finite-step discretization as the dominant ' ...
            'mechanism.\n']);

        fprintf([ ...
            'This does NOT yet establish a production-ready numerical ' ...
            'solution.\n']);

    else

        fprintf([ ...
            'RESULT: violation does not decrease consistently enough ' ...
            'under the tested refinement.\n']);

        fprintf([ ...
            'Do not modify the controller; inspect the numerical ' ...
            'integration mechanism further.\n']);

    end

    fprintf('============================================================\n');

    %% ------------------------------------------------------------
    % Save numerical results
    % -------------------------------------------------------------
    out_file = fullfile( ...
        fileparts(project_root), ...
        'k3_results.txt');

    fid = fopen(out_file, 'w');

    if fid > 0

        fprintf(fid, ...
            ['MaxStepCap,MaxActualStep,' ...
             'Wc0Max,Wc0Violation,' ...
             'Wc1Max,Wc1Violation,' ...
             'Wc2Max,Wc2Violation\n']);

        for r = 1:nruns

            fprintf(fid, ...
                ['%.16e,%.16e,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%.16e\n'], ...
                h_caps(r), ...
                maxStepActual(r), ...
                maxW(r,1), violation(r,1), ...
                maxW(r,2), violation(r,2), ...
                maxW(r,3), violation(r,3));

        end

        fclose(fid);
    end
end
