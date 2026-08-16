function diagnose_stepN1_projection_bound_scale()
% DIAGNOSE_STEPN1_PROJECTION_BOUND_SCALE
%
% Step N.1: Table 1 does NOT specify numeric delta_c / delta_a (the NN
% weight projection ball radii, Eq. 20 / Eq. 38). This project's
% nn_config.m currently guesses delta_c=100, delta_a=50.
%
% Step M.2 (abandoned) + direct inspection of the paper's own Fig. 4
% (Cost-to-go plateauing at O(10^8)) strongly suggest that reading is a
% project placeholder, not a paper-derived value, and is far too small if
% the critic estimate Chat = Wc'*theta_c(chi) (theta_c in [0,1], 15 nodes)
% is meant to explain an O(10^8) cost-to-go.
%
% This script sweeps delta_c across orders of magnitude and, using the
% UNCHANGED tau_cmd_raw reward default (Issue M closed: do not change),
% integrates rhs_3auv_rl over a SHORT horizon (<=2s, NOT a full Phase B/C
% run, per audit Rule 5) to see whether a larger delta_c removes the
% ode45 stiffness/boundary-crossing pathology identified in Issue K.
%
% Safety: a custom OutputFcn aborts any single run after a large step
% count so a pathological (delta_c=100) run cannot hang indefinitely.
%
% NO controller/model modification. NO clipping added to production code.
% Only cfg.delta_c is varied, locally, inside this diagnostic script.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    params  = simulation_params(); % critic_reward_tau_mode default = tau_cmd_raw (unchanged)
    sat_cfg = saturation_config();

    out_file = fullfile(fileparts(project_root), 'n1_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP N.1 -- delta_c / delta_a PROJECTION BOUND SCALE SWEEP\n');
    p('============================================================\n');
    p('critic_reward_tau_mode = %s (unchanged production default)\n', params.critic_reward_tau_mode);

    t_horizon = 2.0; % seconds -- short horizon, NOT a Phase B/C full run
    max_steps = 20000; % hard abort ceiling per run (safety, avoids hangs)

    delta_c_list = [100, 1e4, 1e6, 1e8];
    delta_a_ratio = 0.5; % keep delta_a = 0.5*delta_c (same ratio as current 50/100 default)

    opts_base = odeset('RelTol', 1e-3, 'AbsTol', 1e-4, 'MaxStep', 5e-2, 'Refine', 1);

    p('t_horizon = %.3f s, max_steps abort ceiling = %d\n', t_horizon, max_steps);
    p('delta_c sweep = [%s]\n', sprintf('%.0e ', delta_c_list));

    for k = 1:numel(delta_c_list)

        cfg = nn_config();
        cfg.delta_c = delta_c_list(k);
        cfg.critic_weight_bound = cfg.delta_c;
        cfg.delta_a = delta_c_list(k) * delta_a_ratio;
        cfg.actor_weight_bound = cfg.delta_a;

        [eta_init, nu_init] = initial_conditions();
        omega_aw = zeros(6,3);
        Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
        Wc = zeros(cfg.critic_n_nodes,3);
        X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

        opts = odeset(opts_base, 'OutputFcn', @local_outfcn);
        clear_step_count();

        p('\n------------------------------------------------------------\n');
        p('delta_c = %.3e, delta_a = %.3e\n', cfg.delta_c, cfg.delta_a);
        p('------------------------------------------------------------\n');

        tic;
        solver_error = '';
        try
            [t, X] = ode45(@(tt,xx) rhs_3auv_rl(tt, xx, params, sat_cfg, cfg), ...
                [0 t_horizon], X0, opts);
        catch ME
            t = [0];
            X = X0.';
            solver_error = ME.message;
        end
        elapsed = toc;

        nt = length(t);
        Wc_max = zeros(1,3);
        Wa_max = zeros(1,3);
        for kk = 1:nt
            Xk = X(kk,:).';
            [~, ~, ~, Wa_cell, Wc_mat] = unpack_states(Xk, cfg);
            for i = 1:3
                Wc_max(i) = max(Wc_max(i), norm(Wc_mat(:,i)));
                Wa_max(i) = max(Wa_max(i), norm(Wa_cell{i}, 'fro'));
            end
        end

        final_t = t(end);
        p('elapsed wall time     = %.3f s\n', elapsed);
        p('solver output points  = %d\n', nt);
        p('final integration time= %.6e s (target %.3f s)\n', final_t, t_horizon);
        if ~isempty(solver_error)
            p('SOLVER ERROR          = %s\n', solver_error);
        end
        p('max||Wc|| per AUV     = [%.6e %.6e %.6e]  (delta_c=%.3e)\n', Wc_max, cfg.delta_c);
        p('max||Wa||_F per AUV   = [%.6e %.6e %.6e]  (delta_a=%.3e)\n', Wa_max, cfg.delta_a);

        completed = abs(final_t - t_horizon) < 1e-9;
        p('STATUS                = %s\n', ternary(completed, 'FULL HORIZON COMPLETED', 'STOPPED EARLY / FAILED'));
    end

    p('\n============================================================\n');
    p(' STEP N.1 COMPLETE\n');
    p('============================================================\n');
    p('Interpretation: if larger delta_c allows the FULL 2s horizon to\n');
    p('complete quickly (small elapsed time, reasonable step count) while\n');
    p('delta_c=100 stalls/fails, this supports raising delta_c/delta_a as\n');
    p('the fix for Issue K, instead of (or in addition to) Projected RK4.\n');

    if fid > 0
        fclose(fid);
    end
end

function s = ternary(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end

function status = local_outfcn(t, y, flag)
    status = 0;
    persistent count
    if isempty(flag)
        count = count + 1;
        if count > 20000
            status = 1; % abort
        end
    elseif strcmp(flag, 'init')
        count = 0;
    elseif strcmp(flag, 'done')
        count = [];
    end
end

function clear_step_count()
    local_outfcn([], [], 'init');
end
