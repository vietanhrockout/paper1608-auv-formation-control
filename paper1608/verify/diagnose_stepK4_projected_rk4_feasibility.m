function diagnose_stepK4_projected_rk4_feasibility()
% DIAGNOSE_STEPK4_PROJECTED_RK4_FEASIBILITY
%
% Step K.4:
% Micro-horizon feasibility test for an explicitly projected RK4
% numerical integrator.
%
% IMPORTANT:
%   - rhs_3auv_rl is unchanged
%   - projection_operator is unchanged
%   - unpack_states remains transparent
%   - lambda_c, lambda_a, delta_c, delta_a unchanged
%   - controller and saturation unchanged
%
% The state retraction below is a NUMERICAL INTEGRATOR operation,
% not part of the continuous-time controller/adaptive law.

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

    %% ============================================================
    % Initial state
    % =============================================================
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

    %% ============================================================
    % Micro horizon and refinement sequence
    % =============================================================
    t_final = 8e-5;

    h_list = [ ...
        1e-5, ...
        2e-6, ...
        5e-7, ...
        1e-7];

    nruns = numel(h_list);

    Xend = cell(nruns,1);

    max_post_Wc = zeros(nruns,3);
    max_pre_Wc  = zeros(nruns,3);

    max_post_Wa = zeros(nruns,1);
    max_pre_Wa  = zeros(nruns,1);

    max_retraction = zeros(nruns,1);
    total_retractions = zeros(nruns,1);

    elapsed_time = zeros(nruns,1);
    nsteps_run   = zeros(nruns,1);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.4 -- PROJECTED RK4 FEASIBILITY AUDIT\n');
    fprintf('============================================================\n');

    fprintf('t_final  = %.6e s\n', t_final);
    fprintf('delta_c  = %.6e\n', cfg.delta_c);
    fprintf('delta_a  = %.6e\n', cfg.delta_a);

    %% ============================================================
    % Run refinements
    % =============================================================
    for r = 1:nruns

        h_nom = h_list(r);

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('RUN %d / %d\n', r, nruns);
        fprintf('Nominal h = %.6e s\n', h_nom);
        fprintf('------------------------------------------------------------\n');

        X = X0;
        t = 0;

        % Ensure feasible initial state
        [X, info0] = project_nn_state(X, cfg);

        local_max_pre_c  = info0.pre_c;
        local_max_pre_a  = info0.max_pre_a;
        local_max_retract = info0.correction_norm;
        local_n_retract   = info0.n_retracted;

        local_max_post_c = current_critic_norms(X, cfg);
        local_max_post_a = current_actor_max_norm(X, cfg);

        nsteps = 0;

        tic;

        while t < t_final

            h = min(h_nom, t_final - t);

            [Xnew, step_info] = projected_rk4_step( ...
                t, ...
                X, ...
                h, ...
                params, ...
                sat_cfg, ...
                cfg);

            X = Xnew;
            t = t + h;

            nsteps = nsteps + 1;

            local_max_pre_c = max( ...
                local_max_pre_c, ...
                step_info.max_pre_c);

            local_max_pre_a = max( ...
                local_max_pre_a, ...
                step_info.max_pre_a);

            local_max_retract = max( ...
                local_max_retract, ...
                step_info.max_correction);

            local_n_retract = ...
                local_n_retract + step_info.n_retracted;

            post_c = current_critic_norms(X, cfg);

            post_a = current_actor_max_norm(X, cfg);

            local_max_post_c = max( ...
                local_max_post_c, ...
                post_c);

            local_max_post_a = max( ...
                local_max_post_a, ...
                post_a);
        end

        elapsed = toc;

        Xend{r} = X;

        nsteps_run(r) = nsteps;
        elapsed_time(r) = elapsed;

        max_pre_Wc(r,:)  = local_max_pre_c;
        max_post_Wc(r,:) = local_max_post_c;

        max_pre_Wa(r)  = local_max_pre_a;
        max_post_Wa(r) = local_max_post_a;

        max_retraction(r) = local_max_retract;
        total_retractions(r) = local_n_retract;

        fprintf('steps                  = %d\n', nsteps);
        fprintf('elapsed                = %.3f s\n', elapsed);

        fprintf('\nCritic PRE-projection maxima:\n');

        fprintf('AUV0 = %.12e\n', max_pre_Wc(r,1));
        fprintf('AUV1 = %.12e\n', max_pre_Wc(r,2));
        fprintf('AUV2 = %.12e\n', max_pre_Wc(r,3));

        fprintf('\nCritic POST-projection maxima:\n');

        fprintf('AUV0 = %.12e\n', max_post_Wc(r,1));
        fprintf('AUV1 = %.12e\n', max_post_Wc(r,2));
        fprintf('AUV2 = %.12e\n', max_post_Wc(r,3));

        fprintf('\nActor max PRE  = %.12e\n', max_pre_Wa(r));
        fprintf('Actor max POST = %.12e\n', max_post_Wa(r));

        fprintf('max state retraction norm = %.12e\n', ...
            max_retraction(r));

        fprintf('number of projected vectors = %d\n', ...
            total_retractions(r));

        % Structural bound oracle
        assert(all(max_post_Wc(r,:) <= cfg.delta_c + 1e-10), ...
            'K.4 FAIL: projected Critic state violates delta_c.');

        assert(max_post_Wa(r) <= cfg.delta_a + 1e-10, ...
            'K.4 FAIL: projected Actor state violates delta_a.');
    end

    %% ============================================================
    % Endpoint consistency under refinement
    % =============================================================
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' ENDPOINT REFINEMENT DIFFERENCES\n');
    fprintf('============================================================\n');

    eta_diff = NaN(nruns-1,1);
    nu_diff  = NaN(nruns-1,1);
    Wa_diff  = NaN(nruns-1,1);
    Wc_diff  = NaN(nruns-1,1);

    for r = 1:nruns-1

        [etaA, nuA, ~, WaA, WcA] = ...
            unpack_states(Xend{r}, cfg);

        [etaB, nuB, ~, WaB, WcB] = ...
            unpack_states(Xend{r+1}, cfg);

        eta_diff(r) = max(abs(etaA(:) - etaB(:)));

        nu_diff(r) = max(abs(nuA(:) - nuB(:)));

        Wc_diff(r) = max(abs(WcA(:) - WcB(:)));

        tmp_a = 0;

        for i = 1:3
            tmp_a = max( ...
                tmp_a, ...
                max(abs(WaA{i}(:) - WaB{i}(:))));
        end

        Wa_diff(r) = tmp_a;

        fprintf('\nh = %.3e -> %.3e\n', ...
            h_list(r), h_list(r+1));

        fprintf('max |Delta eta| = %.12e\n', eta_diff(r));
        fprintf('max |Delta nu|  = %.12e\n', nu_diff(r));
        fprintf('max |Delta Wa|  = %.12e\n', Wa_diff(r));
        fprintf('max |Delta Wc|  = %.12e\n', Wc_diff(r));
    end

    %% ============================================================
    % Summary
    % =============================================================
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.4 SUMMARY\n');
    fprintf('============================================================\n');

    fprintf([ ...
        'h          steps    ' ...
        'preWc0      postWc0     ' ...
        'preWc1      postWc1     ' ...
        'preWc2      postWc2     ' ...
        'maxRetract\n']);

    for r = 1:nruns

        fprintf([ ...
            '%.3e  %7d  ' ...
            '%.6e %.6e  ' ...
            '%.6e %.6e  ' ...
            '%.6e %.6e  ' ...
            '%.6e\n'], ...
            h_list(r), ...
            nsteps_run(r), ...
            max_pre_Wc(r,1), ...
            max_post_Wc(r,1), ...
            max_pre_Wc(r,2), ...
            max_post_Wc(r,2), ...
            max_pre_Wc(r,3), ...
            max_post_Wc(r,3), ...
            max_retraction(r));
    end

    fprintf('\n');

    fprintf(['Interpretation rule:\n' ...
        '1) POST norms must satisfy projection bounds structurally.\n' ...
        '2) PRE-projection excursions should shrink with h.\n' ...
        '3) Endpoint differences should shrink under refinement.\n' ...
        '4) No production solver decision is made in K.4.\n']);

    fprintf('============================================================\n');

    %% ============================================================
    % Save
    % =============================================================
    out_file = fullfile( ...
        fileparts(project_root), ...
        'k4_results.txt');

    fid = fopen(out_file, 'w');

    if fid > 0

        fprintf(fid, ...
            ['h,steps,' ...
             'preWc0,postWc0,' ...
             'preWc1,postWc1,' ...
             'preWc2,postWc2,' ...
             'preWa,postWa,' ...
             'maxRetraction,nRetracted,elapsed\n']);

        for r = 1:nruns

            fprintf(fid, ...
                ['%.16e,%d,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%.16e,' ...
                 '%.16e,%d,%.16e\n'], ...
                h_list(r), ...
                nsteps_run(r), ...
                max_pre_Wc(r,1), ...
                max_post_Wc(r,1), ...
                max_pre_Wc(r,2), ...
                max_post_Wc(r,2), ...
                max_pre_Wc(r,3), ...
                max_post_Wc(r,3), ...
                max_pre_Wa(r), ...
                max_post_Wa(r), ...
                max_retraction(r), ...
                total_retractions(r), ...
                elapsed_time(r));
        end

        fclose(fid);
    end
end


%% ========================================================================
function [Xnext, stats] = projected_rk4_step( ...
    t, X, h, params, sat_cfg, cfg)

    % Current feasible state
    [X1, info1] = project_nn_state(X, cfg);

    k1 = rhs_3auv_rl( ...
        t, X1, params, sat_cfg, cfg);

    % Stage 2
    X2_trial = X1 + 0.5*h*k1;

    [X2, info2] = project_nn_state( ...
        X2_trial, cfg);

    k2 = rhs_3auv_rl( ...
        t + 0.5*h, X2, params, sat_cfg, cfg);

    % Stage 3
    X3_trial = X1 + 0.5*h*k2;

    [X3, info3] = project_nn_state( ...
        X3_trial, cfg);

    k3 = rhs_3auv_rl( ...
        t + 0.5*h, X3, params, sat_cfg, cfg);

    % Stage 4
    X4_trial = X1 + h*k3;

    [X4, info4] = project_nn_state( ...
        X4_trial, cfg);

    k4 = rhs_3auv_rl( ...
        t + h, X4, params, sat_cfg, cfg);

    % Full RK4 trial
    Xtrial = X1 + ...
        (h/6) * (k1 + 2*k2 + 2*k3 + k4);

    % Final explicit numerical retraction
    [Xnext, info5] = project_nn_state( ...
        Xtrial, cfg);

    infos = {info1, info2, info3, info4, info5};

    stats.max_pre_c = zeros(1,3);
    stats.max_pre_a = 0;
    stats.max_correction = 0;
    stats.n_retracted = 0;

    for q = 1:numel(infos)

        stats.max_pre_c = max( ...
            stats.max_pre_c, ...
            infos{q}.pre_c);

        stats.max_pre_a = max( ...
            stats.max_pre_a, ...
            infos{q}.max_pre_a);

        stats.max_correction = max( ...
            stats.max_correction, ...
            infos{q}.correction_norm);

        stats.n_retracted = ...
            stats.n_retracted + infos{q}.n_retracted;
    end
end


%% ========================================================================
function [Xproj, info] = project_nn_state(X, cfg)
% Explicit NUMERICAL projection of adaptive states.
%
% This function must NOT be called inside unpack_states or rhs_3auv_rl.
% It belongs only to the projected numerical integrator.

    [eta_mat, nu_mat, omega_mat, Wa_cell, Wc_mat] = ...
        unpack_states(X, cfg);

    pre_c = zeros(1,3);
    max_pre_a = 0;

    n_retracted = 0;

    for i = 1:3

        %% Critic
        nwc = norm(Wc_mat(:,i));

        pre_c(i) = nwc;

        if nwc > cfg.delta_c

            Wc_mat(:,i) = ...
                (cfg.delta_c / nwc) * Wc_mat(:,i);

            n_retracted = n_retracted + 1;
        end

        %% Actor: one projection ball per DOF weight vector
        for j = 1:6

            nwa = norm(Wa_cell{i}(:,j));

            max_pre_a = max(max_pre_a, nwa);

            if nwa > cfg.delta_a

                Wa_cell{i}(:,j) = ...
                    (cfg.delta_a / nwa) * ...
                    Wa_cell{i}(:,j);

                n_retracted = n_retracted + 1;
            end
        end
    end

    Xproj = pack_states( ...
        eta_mat, ...
        nu_mat, ...
        omega_mat, ...
        Wa_cell, ...
        Wc_mat, ...
        cfg);

    info.pre_c = pre_c;
    info.max_pre_a = max_pre_a;

    info.correction_norm = norm(Xproj - X, 2);

    info.n_retracted = n_retracted;
end


%% ========================================================================
function n = current_critic_norms(X, cfg)

    [~, ~, ~, ~, Wc] = unpack_states(X, cfg);

    n = zeros(1,3);

    for i = 1:3
        n(i) = norm(Wc(:,i));
    end
end


%% ========================================================================
function nmax = current_actor_max_norm(X, cfg)

    [~, ~, ~, Wa, ~] = unpack_states(X, cfg);

    nmax = 0;

    for i = 1:3
        for j = 1:6
            nmax = max(nmax, norm(Wa{i}(:,j)));
        end
    end
end
