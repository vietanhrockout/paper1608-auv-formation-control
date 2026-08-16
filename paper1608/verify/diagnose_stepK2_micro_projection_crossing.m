function diagnose_stepK2_micro_projection_crossing()
% DIAGNOSE_STEPK2_MICRO_PROJECTION_CROSSING
%
% Step K.2:
% Audit Critic projection boundary crossing on a micro time horizon.
%
% IMPORTANT:
%   - No controller modification
%   - No clipping
%   - No learning-rate tuning
%   - No projection modification
%   - Same RelTol / AbsTol / MaxStep as exp4_rl_pts_mc
%
% Only Refine=1 is added so solver output mesh can be inspected.

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
    % Micro horizon
    % -------------------------------------------------------------
    t_micro = 2e-4;     % 0.2 ms

    % SAME production tolerances as exp4_rl_pts_mc.
    % Refine=1 is output-only diagnostic configuration.
    opts = odeset( ...
        'RelTol', 1e-3, ...
        'AbsTol', 1e-4, ...
        'MaxStep', 5e-2, ...
        'Refine', 1);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.2 -- MICRO PROJECTION CROSSING AUDIT\n');
    fprintf('============================================================\n');
    fprintf('t_micro = %.6e s\n', t_micro);
    fprintf('delta_c = %.6e\n', delta_c);
    fprintf('RelTol  = 1e-3\n');
    fprintf('AbsTol  = 1e-4\n');
    fprintf('MaxStep = 5e-2  (unchanged production value)\n');

    %% ------------------------------------------------------------
    % IMPORTANT:
    % Two-element tspan exposes solver mesh much more directly than
    % linspace(0,t_final,301).
    % -------------------------------------------------------------
    [t, X] = ode45( ...
        @(tt,xx) rhs_3auv_rl( ...
            tt, xx, params, sat_cfg, cfg), ...
        [0 t_micro], ...
        X0, ...
        opts);

    nt = length(t);

    fprintf('\nSolver output points : %d\n', nt);
    fprintf('Accepted intervals   : %d\n', nt-1);

    if nt > 1
        h = diff(t);

        fprintf('min output step       : %.6e s\n', min(h));
        fprintf('max output step       : %.6e s\n', max(h));
        fprintf('first output step     : %.6e s\n', h(1));
    else
        h = [];
    end

    %% ------------------------------------------------------------
    % Diagnostic histories
    % -------------------------------------------------------------
    Wnorm     = zeros(nt,3);

    rawNorm   = zeros(nt,3);
    projNorm  = zeros(nt,3);

    radialRaw = zeros(nt,3);
    radialProj= zeros(nt,3);

    costHist  = zeros(nt,3);
    tauForce  = zeros(nt,3);

    for k = 1:nt

        Xk = X(k,:).';

        [eta_mat, nu_mat, omega_mat, Wa_cell, Wc_mat] = ...
            unpack_states(Xk, cfg);

        for i = 1:3

            eta = eta_mat(:,i);
            nu  = nu_mat(:,i);

            Wci = Wc_mat(:,i);
            Wai = Wa_cell{i};

            J = jacobian_J(eta);
            eta_dot = J * nu;

            [chi, vel_err] = formation_error( ...
                eta, eta_dot, t(k), i);

            tau_cmd = controller_rl( ...
                eta, eta_dot, t(k), i, ...
                omega_mat(:,i), ...
                Wai, ...
                params, ...
                cfg);

            [ce, Phi] = bellman_error( ...
                chi, ...
                vel_err, ...
                Wci, ...
                tau_cmd, ...
                params, ...
                cfg);

            v_raw = ...
                -params.lambda_c * ce * Phi;

            v_proj = projection_operator( ...
                Wci, ...
                v_raw, ...
                delta_c);

            Wnorm(k,i) = norm(Wci);

            rawNorm(k,i)  = norm(v_raw);
            projNorm(k,i) = norm(v_proj);

            radialRaw(k,i)  = Wci' * v_raw;
            radialProj(k,i) = Wci' * v_proj;

            costHist(k,i) = ...
                strategic_utility(chi, tau_cmd);

            tauForce(k,i) = ...
                max(abs(tau_cmd(1:3)));

        end
    end

    %% ------------------------------------------------------------
    % Save complete micro mesh
    % -------------------------------------------------------------
    out_file = fullfile( ...
        fileparts(project_root), ...
        'k2_results.txt');

    fid = fopen(out_file,'w');

    if fid > 0

        fprintf(fid, ...
            ['k,t,h,Wc0,Wc1,Wc2,' ...
             'rawRad0,rawRad1,rawRad2,' ...
             'projRad0,projRad1,projRad2\n']);

        for k = 1:nt

            if k == 1
                hk = 0;
            else
                hk = t(k)-t(k-1);
            end

            fprintf(fid, ...
                ['%d,%.16e,%.16e,' ...
                 '%.16e,%.16e,%.16e,' ...
                 '%.16e,%.16e,%.16e,' ...
                 '%.16e,%.16e,%.16e\n'], ...
                k, t(k), hk, ...
                Wnorm(k,1), ...
                Wnorm(k,2), ...
                Wnorm(k,3), ...
                radialRaw(k,1), ...
                radialRaw(k,2), ...
                radialRaw(k,3), ...
                radialProj(k,1), ...
                radialProj(k,2), ...
                radialProj(k,3));
        end
    end

    %% ------------------------------------------------------------
    % Boundary-crossing classification
    % -------------------------------------------------------------
    vector_field_violation = false;
    numerical_crossing     = false;

    for i = 1:3

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('AUV %d\n', i-1);
        fprintf('------------------------------------------------------------\n');

        fprintf('max ||Wc|| over micro horizon = %.12e\n', ...
            max(Wnorm(:,i)));

        % First point >= 90% boundary
        idx90 = find( ...
            Wnorm(:,i) >= 0.9*delta_c, ...
            1, 'first');

        if ~isempty(idx90)
            fprintf('first ||Wc|| >= 0.9 delta at t = %.12e s\n', ...
                t(idx90));
            fprintf('  ||Wc|| = %.12e\n', ...
                Wnorm(idx90,i));
        else
            fprintf('||Wc|| never reached 0.9 delta.\n');
        end

        % First actual outside-boundary state
        idx = find( ...
            Wnorm(:,i) > delta_c + 1e-6, ...
            1, 'first');

        if isempty(idx)

            fprintf('No boundary violation in this micro horizon.\n');
            continue;
        end

        if idx == 1
            error('K.2 unexpected: initial Wc already outside boundary.');
        end

        kp = idx - 1;

        h_cross = t(idx) - t(kp);

        fprintf('\nFIRST OUTSIDE-BOUNDARY OUTPUT:\n');

        fprintf('t_prev    = %.16e s\n', t(kp));
        fprintf('t_outside = %.16e s\n', t(idx));
        fprintf('h_cross   = %.16e s\n', h_cross);

        fprintf('||Wc_prev||    = %.16e\n', ...
            Wnorm(kp,i));

        fprintf('||Wc_outside|| = %.16e\n', ...
            Wnorm(idx,i));

        fprintf('overshoot ratio = %.16e\n', ...
            Wnorm(idx,i)/delta_c);

        fprintf('||v_raw|| outside  = %.16e\n', ...
            rawNorm(idx,i));

        fprintf('||v_proj|| outside = %.16e\n', ...
            projNorm(idx,i));

        fprintf('Wc''*v_raw outside  = %.16e\n', ...
            radialRaw(idx,i));

        fprintf('Wc''*v_proj outside = %.16e\n', ...
            radialProj(idx,i));

        fprintf('r outside             = %.16e\n', ...
            costHist(idx,i));

        fprintf('max tau_cmd force     = %.16e N\n', ...
            tauForce(idx,i));

        % Scale-aware radial test
        radial_scale = max( ...
            1, ...
            Wnorm(idx,i)*projNorm(idx,i));

        normalized_proj_radial = ...
            radialProj(idx,i) / radial_scale;

        fprintf('normalized projected radial = %.16e\n', ...
            normalized_proj_radial);

        % ---------------------------------------------------------
        % Classification
        % ---------------------------------------------------------
        if radialProj(idx,i) > 1e-9*radial_scale

            fprintf('\nCLASSIFICATION:\n');
            fprintf('VECTOR-FIELD PROJECTION VIOLATION SUSPECTED.\n');

            vector_field_violation = true;

        else

            if Wnorm(kp,i) < delta_c

                fprintf('\nCLASSIFICATION:\n');
                fprintf(['STATE CROSSED FROM INSIDE TO OUTSIDE WHILE ' ...
                         'PROJECTED RADIAL DERIVATIVE IS NON-OUTWARD.\n']);

                fprintf(['This is evidence of finite-step numerical ' ...
                         'loss of the invariant set.\n']);

                numerical_crossing = true;

            else

                fprintf('\nCLASSIFICATION:\n');
                fprintf(['State was already outside at previous solver ' ...
                         'output; inspect earlier mesh entries.\n']);
            end
        end
    end

    %% ------------------------------------------------------------
    % Overall result
    % -------------------------------------------------------------
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.2 CLASSIFICATION\n');
    fprintf('============================================================\n');

    if vector_field_violation

        fprintf(['RESULT: possible projection vector-field bug.\n' ...
                 'Do NOT tune solver yet.\n']);

    elseif numerical_crossing

        fprintf(['RESULT: finite-step numerical projection crossing ' ...
                 'is supported by the micro-horizon data.\n']);

    else

        fprintf(['RESULT: no crossing detected inside current ' ...
                 'micro horizon.\n']);

        fprintf(['Do not draw a conclusion yet; extend only the ' ...
                 'diagnostic horizon next.\n']);
    end

    fprintf('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end
