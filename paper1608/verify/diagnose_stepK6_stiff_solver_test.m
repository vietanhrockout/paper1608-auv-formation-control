function diagnose_stepK6_stiff_solver_test(solver_name, t_final)
% DIAGNOSE_STEPK6_STIFF_SOLVER_TEST
%
% Step K.6: Test MATLAB's built-in stiff ODE solvers (ode15s, ode23s,
% ode23t, ode23tb) directly on rhs_3auv_rl from t=0, as an alternative to
% the hand-rolled Projected-RK4 hybrid integrator (Step K.5), which was
% invalidated by diagnose_stepK5_coldphase_instrumented.m: the stiffness
% at the critic-weight projection boundary (||Wc|| pinned exactly at
% delta_c) is PERSISTENT, not a brief initial transient, so no finite
% "hot phase" hand-off to ode45 can work.
%
% Rationale: ode45 is an explicit, non-stiff-oriented solver (Dormand-
% Prince RK4(5)). MATLAB's ode15s (variable-order NDF/BDF, implicit) and
% ode23s (modified Rosenbrock, implicit, low order but robust for mild-
% to-moderate stiffness) are specifically designed for exactly this
% class of problem: fast + slow dynamics coexisting, states pinned at a
% boundary. This is the standard first thing to try for a stiff ODE
% BEFORE hand-rolling a custom fixed-step integrator.
%
% Uses the SAME production tolerances as exp4_rl_pts_mc.m
% (RelTol=1e-3, AbsTol=1e-4) so results are directly comparable.
%
% NO controller/model modification.

    if nargin < 1 || isempty(solver_name)
        solver_name = 'ode15s';
    end
    if nargin < 2 || isempty(t_final)
        t_final = 2.0;
    end

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

    fprintf('\n============================================================\n');
    fprintf(' STEP K.6 -- STIFF SOLVER TEST: %s\n', upper(solver_name));
    fprintf('============================================================\n');
    fprintf('t_final = %.4f s, RelTol=1e-3, AbsTol=1e-4 (production values)\n', t_final);

    [eta_init, nu_init] = initial_conditions();
    omega_aw = zeros(6,3);
    Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
    Wc = zeros(cfg.critic_n_nodes,3);
    X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

    opts = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'OutputFcn', @progress_fcn);

    solver_fn = str2func(solver_name);

    tic;
    try
        [t, X] = solver_fn(@(tt,xx) rhs_3auv_rl(tt, xx, params, sat_cfg, cfg), [0 t_final], X0, opts);
        err_msg = '';
    catch ME
        t = 0;
        X = X0.';
        err_msg = ME.message;
    end
    elapsed = toc;

    nt = numel(t);
    fprintf('\nRESULT: solver=%s elapsed=%.3fs points=%d final_t=%.6f (target %.4f)\n', ...
        solver_name, elapsed, nt, t(end), t_final);
    if ~isempty(err_msg)
        fprintf('SOLVER ERROR: %s\n', err_msg);
    end

    Wc_max = zeros(1,3);
    for k = 1:nt
        Xk = X(k,:).';
        [~, ~, ~, ~, Wc_mat] = unpack_states(Xk, cfg);
        for i = 1:3
            Wc_max(i) = max(Wc_max(i), norm(Wc_mat(:,i)));
        end
    end
    fprintf('max||Wc|| per AUV = [%.6e %.6e %.6e] (delta_c=%.1f)\n', Wc_max, cfg.delta_c);

    completed = abs(t(end) - t_final) < 1e-9;
    fprintf('STATUS: %s\n', merge_str(completed, 'FULL HORIZON COMPLETED', 'STOPPED EARLY'));

    out_file = fullfile(fileparts(project_root), sprintf('k6_%s_result.txt', solver_name));
    fid = fopen(out_file, 'w');
    if fid > 0
        fprintf(fid, 'solver,elapsed,points,final_t,completed,Wc0,Wc1,Wc2\n');
        fprintf(fid, '%s,%.6f,%d,%.6f,%d,%.6e,%.6e,%.6e\n', ...
            solver_name, elapsed, nt, t(end), completed, Wc_max);
        fclose(fid);
    end
end

function s = merge_str(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end

function status = progress_fcn(t, ~, flag)
    status = 0;
    persistent nsteps last_print
    if isempty(flag)
        nsteps = nsteps + 1;
        if isempty(last_print) || toc(last_print) > 2.0
            fprintf('  progress: accepted_steps=%d t=%.6f\n', nsteps, t(end));
            last_print = tic;
        end
    elseif strcmp(flag, 'init')
        nsteps = 0;
        last_print = tic;
        fprintf('  progress: init at t=%.6f\n', t(1));
    elseif strcmp(flag, 'done')
        nsteps = [];
        last_print = [];
    end
end
