function diagnose_stepM2_micro_horizon_fix_verification()
% DIAGNOSE_STEPM2_MICRO_HORIZON_FIX_VERIFICATION
%
% Step M.2: Re-run the Step K.2-style micro-horizon ode45 boundary-crossing
% audit under BOTH critic_reward_tau_mode candidates ('tau_cmd_raw' current
% default vs 'tau_act_saturated' candidate fix, Issue M / config/paper_params.m)
% to empirically confirm whether the candidate fix resolves Issue K's
% critic-weight projection-ball boundary crossing, using the SAME production
% ode45 tolerances as exp4_rl_pts_mc and Step K.2.
%
% NO controller/model modification. NO clipping. NO solver replacement.
% Only params.critic_reward_tau_mode is toggled (already-implemented,
% documented flag; default production behavior is unchanged by this script).

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    cfg     = nn_config();
    sat_cfg = saturation_config();
    delta_c = cfg.delta_c;
    delta_a = cfg.delta_a;

    out_file = fullfile(fileparts(project_root), 'm2_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP M.2 -- MICRO-HORIZON FIX VERIFICATION (BOTH MODES)\n');
    p('============================================================\n');

    modes = {'tau_cmd_raw', 'tau_act_saturated'};

    % Longer than K.2's 2e-4s -- we specifically want to see whether the
    % candidate fix survives well past where 'tau_cmd_raw' blows up.
    t_micro = 0.05; % 50 ms

    opts = odeset( ...
        'RelTol', 1e-3, ...
        'AbsTol', 1e-4, ...
        'MaxStep', 5e-2, ...
        'Refine', 1);

    p('t_micro = %.6e s\n', t_micro);
    p('delta_c = %.6e, delta_a = %.6e\n', delta_c, delta_a);
    p('RelTol=1e-3, AbsTol=1e-4, MaxStep=5e-2 (production values)\n');

    results = struct();

    for m = 1:numel(modes)

        mode = modes{m};

        params = paper_params();
        params.sigma_mode = 'eq29_consistent';
        params = derived_params(params);
        params.critic_reward_tau_mode = mode;

        [eta_init, nu_init] = initial_conditions();
        omega_aw = zeros(6,3);
        Wa = {zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6), zeros(cfg.actor_n_nodes,6)};
        Wc = zeros(cfg.critic_n_nodes,3);

        X0 = pack_states(eta_init, nu_init, omega_aw, Wa, Wc, cfg);

        p('\n------------------------------------------------------------\n');
        p('MODE: %s\n', mode);
        p('------------------------------------------------------------\n');

        try
            [t, X] = ode45( ...
                @(tt,xx) rhs_3auv_rl(tt, xx, params, sat_cfg, cfg), ...
                [0 t_micro], X0, opts);
            solver_error = '';
        catch ME
            t = [0];
            X = X0.';
            solver_error = ME.message;
        end

        nt = length(t);
        p('Solver output points : %d\n', nt);
        if ~isempty(solver_error)
            p('SOLVER ERROR: %s\n', solver_error);
        end

        Wc_norm_max = zeros(1,3);
        Wa_norm_max = zeros(1,3);
        boundary_hit = false(1,3);
        first_violation_t = Inf(1,3);

        for k = 1:nt
            Xk = X(k,:).';
            [~, ~, ~, Wa_cell, Wc_mat] = unpack_states(Xk, cfg);
            for i = 1:3
                wn = norm(Wc_mat(:,i));
                wan = norm(Wa_cell{i}, 'fro');
                Wc_norm_max(i) = max(Wc_norm_max(i), wn);
                Wa_norm_max(i) = max(Wa_norm_max(i), wan);
                if wn > delta_c + 1e-6 && ~boundary_hit(i)
                    boundary_hit(i) = true;
                    first_violation_t(i) = t(k);
                end
            end
        end

        for i = 1:3
            p('AUV%d: max||Wc|| over horizon = %.6e (delta_c=%.1f), max||Wa||_F = %.6e (delta_a=%.1f)\n', ...
                i-1, Wc_norm_max(i), delta_c, Wa_norm_max(i), delta_a);
            if boundary_hit(i)
                p('  BOUNDARY VIOLATION at t = %.6e s (||Wc|| exceeded delta_c)\n', first_violation_t(i));
            else
                p('  No boundary violation observed in this micro horizon.\n');
            end
        end

        final_t = t(end);
        p('Final integration time reached: %.6e s (target %.6e s) %s\n', ...
            final_t, t_micro, ternary_str(abs(final_t-t_micro)<1e-9, '[FULL HORIZON COMPLETED]', '[SOLVER STOPPED EARLY]'));

        results.(matlab.lang.makeValidName(mode)).Wc_norm_max = Wc_norm_max;
        results.(matlab.lang.makeValidName(mode)).boundary_hit = boundary_hit;
        results.(matlab.lang.makeValidName(mode)).final_t = final_t;
        results.(matlab.lang.makeValidName(mode)).solver_error = solver_error;
    end

    %% ============================================================
    % Verdict
    % =============================================================

    p('\n============================================================\n');
    p(' STEP M.2 VERDICT\n');
    p('============================================================\n');

    r_raw = results.tau_cmd_raw;
    r_sat = results.tau_act_saturated;

    p('tau_cmd_raw (current default) : final_t=%.6e, any boundary hit=%d, solver_error=%s\n', ...
        r_raw.final_t, any(r_raw.boundary_hit), r_raw.solver_error);
    p('tau_act_saturated (candidate) : final_t=%.6e, any boundary hit=%d, solver_error=%s\n', ...
        r_sat.final_t, any(r_sat.boundary_hit), r_sat.solver_error);

    if any(r_raw.boundary_hit) && ~any(r_sat.boundary_hit) && abs(r_sat.final_t - t_micro) < 1e-9
        p('\nCONCLUSION: candidate fix (tau_act_saturated) ELIMINATES the Step K\n');
        p('critic-weight projection-ball boundary crossing over this micro horizon,\n');
        p('while the current default (tau_cmd_raw) still exhibits it.\n');
        p('RECOMMENDATION: promote tau_act_saturated to the production default,\n');
        p('with this diagnostic chain (L.3e -> M.1 -> M.2) as the documented\n');
        p('theoretical + empirical justification required by audit Rule 1.\n');
    else
        p('\nCONCLUSION: candidate fix does NOT fully eliminate the boundary\n');
        p('crossing in this micro horizon alone; further diagnosis needed\n');
        p('(e.g. combine with Step K.4 Projected RK4, or extend horizon).\n');
    end

    if fid > 0
        fclose(fid);
    end
end

function s = ternary_str(cond, a, b)
    if cond
        s = a;
    else
        s = b;
    end
end
