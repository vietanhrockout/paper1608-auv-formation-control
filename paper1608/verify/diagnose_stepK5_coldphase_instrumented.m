function diagnose_stepK5_coldphase_instrumented(t_cold_final)
% DIAGNOSE_STEPK5_COLDPHASE_INSTRUMENTED
%
% Loads the Step K.5 hot-phase checkpoint (k5_hotphase_checkpoint.mat,
% produced by run_k5_checkpoint_hotphase.m) and runs the ode45 "cold
% phase" from t_hot=0.15s to t_hot+t_cold_final, WITH an OutputFcn that
% prints progress every ~2s of wall time -- unlike the original
% exp4_rl_pts_mc_hybrid.m cold-phase call, which had no progress
% visibility and left a 30+ minute run silent with no way to tell
% whether it was still stiff or just slow.
%
% Purpose: quickly determine (on a short horizon first) whether ode45
% genuinely remains stiff past the hot phase, or whether the original
% 2s validation run was simply progressing slower than expected.

    if nargin < 1 || isempty(t_cold_final)
        t_cold_final = 0.1;
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

    t_hot = 0.15;
    t_final = t_hot + t_cold_final;

    fprintf('\n============================================================\n');
    fprintf(' STEP K.5 -- INSTRUMENTED COLD-PHASE TEST\n');
    fprintf('============================================================\n');
    fprintf('cold phase: [%.4f, %.4f]s (duration %.4fs)\n', t_hot, t_final, t_cold_final);

    cfg = ck.cfg;
    Wc_check = [];
    [~, ~, ~, ~, Wc_e] = unpack_states(ck.X_hot_end, cfg);
    for i=1:3
        fprintf('  AUV%d ||Wc|| at hot-phase end = %.6f (delta_c=%.1f)\n', i-1, norm(Wc_e(:,i)), cfg.delta_c);
    end

    opts = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 5e-2, 'Refine', 1, ...
        'OutputFcn', @progress_fcn);

    tic;
    try
        [t, X] = ode45(@(tt,xx) rhs_3auv_rl(tt, xx, ck.params, ck.sat_cfg, ck.cfg), ...
            [t_hot t_final], ck.X_hot_end, opts);
        err_msg = '';
    catch ME
        t = t_hot;
        X = ck.X_hot_end.';
        err_msg = ME.message;
    end
    elapsed = toc;

    fprintf('\nRESULT: elapsed=%.3fs, points=%d, final_t=%.6f (target %.6f)\n', ...
        elapsed, numel(t), t(end), t_final);
    if ~isempty(err_msg)
        fprintf('SOLVER ERROR: %s\n', err_msg);
    end
    if abs(t(end)-t_final) < 1e-9
        fprintf('STATUS: FULL COLD-PHASE SEGMENT COMPLETED\n');
    else
        fprintf('STATUS: STOPPED EARLY / STILL SLOW\n');
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
