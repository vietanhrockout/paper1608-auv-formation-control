function diagnose_stepN1_single_delta(delta_c_val, t_horizon)
% DIAGNOSE_STEPN1_SINGLE_DELTA
%
% Single-case variant of Step N.1: integrate rhs_3auv_rl over a short
% horizon with a given cfg.delta_c (and delta_a = 0.5*delta_c), under the
% tau_cmd_raw critic reward default AS IT STOOD WHEN WRITTEN (SUPERSEDED 2026-08-18). Run each delta_c value as
% its OWN OS process (see run_n1_single.m) so a pathological case (e.g.
% delta_c=100, already suspected from Issue K/M.2 to hang under ode45)
% can be killed by an external wall-clock timeout without blocking the
% other cases.
%
% NO controller/model modification. cfg.delta_c/delta_a varied locally.

    if nargin < 1 || isempty(delta_c_val)
        delta_c_val = 100;
    end
    if nargin < 2 || isempty(t_horizon)
        t_horizon = 2.0;
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

    cfg = nn_config();
    cfg.delta_c = delta_c_val;
    cfg.critic_weight_bound = cfg.delta_c;
    cfg.delta_a = delta_c_val * 0.5;
    cfg.actor_weight_bound = cfg.delta_a;

    fprintf('\n============================================================\n');
    fprintf(' STEP N.1 SINGLE CASE: delta_c = %.3e, delta_a = %.3e, horizon=%.3fs\n', ...
        cfg.delta_c, cfg.delta_a, t_horizon);
    fprintf('============================================================\n');

    [eta_init, nu_init] = initial_conditions();
    omega_aw = zeros(6,3);
    Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
    Wc = zeros(cfg.critic_n_nodes,3);
    X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

    opts = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 5e-2, 'Refine', 1, ...
        'OutputFcn', @report_progress);

    tic;
    [t, X] = ode45(@(tt,xx) rhs_3auv_rl(tt, xx, params, sat_cfg, cfg), [0 t_horizon], X0, opts);
    elapsed = toc;

    nt = length(t);
    Wc_max = zeros(1,3);
    for kk = 1:nt
        Xk = X(kk,:).';
        [~, ~, ~, ~, Wc_mat] = unpack_states(Xk, cfg);
        for i = 1:3
            Wc_max(i) = max(Wc_max(i), norm(Wc_mat(:,i)));
        end
    end

    final_t = t(end);
    completed = abs(final_t - t_horizon) < 1e-9;

    fprintf('\nRESULT: delta_c=%.3e  elapsed=%.3fs  points=%d  final_t=%.6e  status=%s\n', ...
        cfg.delta_c, elapsed, nt, final_t, ...
        merge_str(completed, 'FULL HORIZON COMPLETED', 'STOPPED EARLY'));
    fprintf('max||Wc|| per AUV = [%.6e %.6e %.6e]\n', Wc_max);

    out_file = fullfile(fileparts(project_root), sprintf('n1_single_%d.txt', round(log10(delta_c_val))));
    fid = fopen(out_file, 'w');
    if fid > 0
        fprintf(fid, 'delta_c,elapsed,points,final_t,completed,Wc0,Wc1,Wc2\n');
        fprintf(fid, '%.6e,%.6f,%d,%.6e,%d,%.6e,%.6e,%.6e\n', ...
            cfg.delta_c, elapsed, nt, final_t, completed, Wc_max);
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

function status = report_progress(t, ~, flag)
    status = 0;
    persistent nsteps last_print_time
    if isempty(flag)
        nsteps = nsteps + 1;
        if isempty(last_print_time) || toc(last_print_time) > 2.0
            fprintf('  progress: step=%d t=%.6e\n', nsteps, t(end));
            last_print_time = tic;
        end
        if nsteps > 50000
            fprintf('  ABORT: exceeded 50000 accepted steps.\n');
            status = 1;
        end
    elseif strcmp(flag, 'init')
        nsteps = 0;
        last_print_time = tic;
    elseif strcmp(flag, 'done')
        nsteps = [];
        last_print_time = [];
    end
end
