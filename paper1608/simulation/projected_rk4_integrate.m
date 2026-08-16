function [t_hot, X_hot, stats] = projected_rk4_integrate(t_hot_final, h, X0, params, sat_cfg, cfg, opts)
% PROJECTED_RK4_INTEGRATE Fixed-step explicit RK4 with per-stage NN weight
% ball retraction, for the closed-loop Paper 1608 RL PT-SMC system
% (Issue K/N; now the sole production integrator, Step K.7/Issue P).
%
% Step N.1 established that the ode45 stiffness during the first ~20 ms
% is an intrinsic consequence of the raw command scale (Issue L, expected
% and paper-faithful per Fig. 4 -- Issue M), NOT the projection-ball
% radius (Issue N, delta_c/delta_a rejected as the lever). Step K.4
% validated that an explicitly-projected fixed-step RK4 stepper keeps the
% NN weight states inside their projection balls exactly. Steps K.5/K.6
% showed there is no non-stiff "cold phase" to hand off to (ode45/ode15s
% both stall indefinitely past any tested hot-phase length), so this
% stepper now runs the ENTIRE horizon, not just a hot phase.
%
% rhs_3auv_rl, projection_operator, unpack_states/pack_states are
% UNCHANGED. The projection here is a NUMERICAL INTEGRATOR retraction
% operation only (same role as Step K.4), not a controller/model change.
%
% Inputs:
%   t_hot_final : integration end time (s)
%   h           : fixed step size (s)
%   X0          : initial 549-state vector
%   params, sat_cfg, cfg : as elsewhere
%   opts        : OPTIONAL struct (Phase C.0 gate fix -- memory safety):
%     .store_stride       : store 1 out of every N steps (default 1, i.e.
%                            store every step -- IDENTICAL behavior to the
%                            pre-C.0-gate version for all existing callers
%                            that omit opts). At h=1e-4 over 100s, nsteps=
%                            1e6 and the old always-store-every-step
%                            behavior needs X_hot ~= 1e6 x 549 x 8 bytes
%                            ~= 4.4GB -- set store_stride>1 for long runs.
%     .checkpoint_every_sec : if >0, write a .mat checkpoint (t, X, step
%                            count, running stats) to opts.checkpoint_path
%                            every this many seconds of SIMULATED time
%                            (default 0 = disabled). Safety snapshot only
%                            (crash/kill recovery diagnostics) -- this
%                            function does not itself resume from a
%                            checkpoint.
%     .checkpoint_path    : path for the above (default
%                            'projected_rk4_checkpoint.mat').
%
% Outputs:
%   t_hot : column vector of stored time points (length depends on
%           store_stride; always includes t=0 and the final time)
%   X_hot : [numel(t_hot) x numState] state history at the stored points
%   stats : struct with step count, max retraction norm, wall time

    if nargin < 7 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'store_stride') || isempty(opts.store_stride)
        opts.store_stride = 1;
    end
    if ~isfield(opts, 'checkpoint_every_sec') || isempty(opts.checkpoint_every_sec)
        opts.checkpoint_every_sec = 0;
    end
    if ~isfield(opts, 'checkpoint_path') || isempty(opts.checkpoint_path)
        opts.checkpoint_path = 'projected_rk4_checkpoint.mat';
    end

    nsteps = ceil(t_hot_final / h);
    n_store_cap = floor(nsteps / opts.store_stride) + 2; % +2: t=0 slot and a safety slot for a non-aligned final step

    t_hot = zeros(n_store_cap, 1);
    X_hot = zeros(n_store_cap, numel(X0));

    X = X0(:);
    t = 0;

    store_idx = 1;
    t_hot(1) = 0;
    X_hot(1,:) = X.';

    max_retraction = 0;
    total_retracted = 0;
    last_checkpoint_t = 0;

    tic;
    for k = 1:nsteps

        hk = min(h, t_hot_final - t);

        [Xnext, step_info] = local_projected_rk4_step(t, X, hk, params, sat_cfg, cfg);

        X = Xnext;
        t = t + hk;

        max_retraction = max(max_retraction, step_info.max_correction);
        total_retracted = total_retracted + step_info.n_retracted;

        if mod(k, opts.store_stride) == 0 || k == nsteps
            store_idx = store_idx + 1;
            t_hot(store_idx) = t;
            X_hot(store_idx,:) = X.';
        end

        if opts.checkpoint_every_sec > 0 && (t - last_checkpoint_t) >= opts.checkpoint_every_sec
            last_checkpoint_t = t;
            checkpoint = struct('t', t, 'X', X, 'k', k, 'nsteps', nsteps, ...
                'max_retraction', max_retraction, 'total_retracted', total_retracted);
            save(opts.checkpoint_path, 'checkpoint');
        end
    end
    elapsed = toc;

    t_hot = t_hot(1:store_idx);
    X_hot = X_hot(1:store_idx, :);

    stats = struct();
    stats.nsteps = nsteps;
    stats.max_retraction = max_retraction;
    stats.total_retracted = total_retracted;
    stats.elapsed = elapsed;
end


function [Xnext, stats] = local_projected_rk4_step(t, X, h, params, sat_cfg, cfg)

    [X1, info1] = local_project_nn_state(X, cfg);
    k1 = rhs_3auv_rl(t, X1, params, sat_cfg, cfg);

    [X2, info2] = local_project_nn_state(X1 + 0.5*h*k1, cfg);
    k2 = rhs_3auv_rl(t + 0.5*h, X2, params, sat_cfg, cfg);

    [X3, info3] = local_project_nn_state(X1 + 0.5*h*k2, cfg);
    k3 = rhs_3auv_rl(t + 0.5*h, X3, params, sat_cfg, cfg);

    [X4, info4] = local_project_nn_state(X1 + h*k3, cfg);
    k4 = rhs_3auv_rl(t + h, X4, params, sat_cfg, cfg);

    Xtrial = X1 + (h/6) * (k1 + 2*k2 + 2*k3 + k4);

    [Xnext, info5] = local_project_nn_state(Xtrial, cfg);

    infos = {info1, info2, info3, info4, info5};

    stats.max_correction = 0;
    stats.n_retracted = 0;
    for q = 1:numel(infos)
        stats.max_correction = max(stats.max_correction, infos{q}.correction_norm);
        stats.n_retracted = stats.n_retracted + infos{q}.n_retracted;
    end
end


function [Xproj, info] = local_project_nn_state(X, cfg)
% Same logic as diagnose_stepK4_projected_rk4_feasibility.m's
% project_nn_state, duplicated here (production integrator must not
% depend on files under paper1608/verify/).

    [eta_mat, nu_mat, omega_mat, Wa_cell, Wc_mat] = unpack_states(X, cfg);

    n_retracted = 0;

    for i = 1:3

        nwc = norm(Wc_mat(:,i));
        if nwc > cfg.delta_c
            Wc_mat(:,i) = (cfg.delta_c / nwc) * Wc_mat(:,i);
            n_retracted = n_retracted + 1;
        end

        for j = 1:6
            nwa = norm(Wa_cell{i}(:,j));
            if nwa > cfg.delta_a
                Wa_cell{i}(:,j) = (cfg.delta_a / nwa) * Wa_cell{i}(:,j);
                n_retracted = n_retracted + 1;
            end
        end
    end

    Xproj = pack_states(eta_mat, nu_mat, omega_mat, Wa_cell, Wc_mat, cfg);

    info.correction_norm = norm(Xproj - X, 2);
    info.n_retracted = n_retracted;
end
