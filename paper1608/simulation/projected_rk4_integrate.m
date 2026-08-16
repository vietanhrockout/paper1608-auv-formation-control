function [t_hot, X_hot, stats] = projected_rk4_integrate(t_hot_final, h, X0, params, sat_cfg, cfg)
% PROJECTED_RK4_INTEGRATE Fixed-step explicit RK4 with per-stage NN weight
% ball retraction, for the "hot" initial transient of the closed-loop
% Paper 1608 RL PT-SMC system (Issue K/N).
%
% Step N.1 established that the ode45 stiffness during the first ~20 ms
% is an intrinsic consequence of the raw command scale (Issue L, expected
% and paper-faithful per Fig. 4 -- Issue M), NOT the projection-ball
% radius (Issue N, delta_c/delta_a rejected as the lever). Step K.4
% validated that an explicitly-projected fixed-step RK4 stepper keeps the
% NN weight states inside their projection balls exactly, at micro-horizon
% scale. This function extends that validated stepper to an arbitrary
% "hot phase" horizon with a fixed step h, for use as the first phase of
% a hybrid integrator (see exp4_rl_pts_mc_hybrid.m), before handing off
% to standard ode45 for the remainder of the simulation.
%
% rhs_3auv_rl, projection_operator, unpack_states/pack_states are
% UNCHANGED. The projection here is a NUMERICAL INTEGRATOR retraction
% operation only (same role as Step K.4), not a controller/model change.
%
% Inputs:
%   t_hot_final : hot-phase end time (s)
%   h           : fixed step size (s)
%   X0          : initial 549-state vector
%   params, sat_cfg, cfg : as elsewhere
%
% Outputs:
%   t_hot : column vector of time points (0:h:t_hot_final, last point clipped)
%   X_hot : [numel(t_hot) x numState] state history
%   stats : struct with step count, max retraction norm, wall time

    nsteps = ceil(t_hot_final / h);

    t_hot = zeros(nsteps+1, 1);
    X_hot = zeros(nsteps+1, numel(X0));

    X = X0(:);
    t = 0;

    t_hot(1) = 0;
    X_hot(1,:) = X.';

    max_retraction = 0;
    total_retracted = 0;

    tic;
    for k = 1:nsteps

        hk = min(h, t_hot_final - t);

        [Xnext, step_info] = local_projected_rk4_step(t, X, hk, params, sat_cfg, cfg);

        X = Xnext;
        t = t + hk;

        max_retraction = max(max_retraction, step_info.max_correction);
        total_retracted = total_retracted + step_info.n_retracted;

        t_hot(k+1) = t;
        X_hot(k+1,:) = X.';
    end
    elapsed = toc;

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
