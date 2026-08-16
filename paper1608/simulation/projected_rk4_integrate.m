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
%   X0          : initial 549-state vector (ignored if opts.resume is set)
%   params, sat_cfg, cfg : as elsewhere
%   opts        : OPTIONAL struct:
%     .store_stride       : store 1 out of every N steps (default 1, i.e.
%                            store every step). At h=1e-4 over 100s,
%                            nsteps=1e6 and always-store-every-step needs
%                            X_hot ~= 1e6 x 549 x 8 bytes ~= 4.4GB -- set
%                            store_stride>1 for long runs.
%     .checkpoint_every_sec : if >0, write a .mat checkpoint to
%                            opts.checkpoint_path every this many seconds
%                            of SIMULATED time (default 0 = disabled).
%                            Written ATOMICALLY (temp file + rename) so a
%                            kill mid-write cannot corrupt the last valid
%                            checkpoint. Phase C.0 gate round 2 (GPT
%                            audit): the checkpoint now carries everything
%                            needed to resume safely and reconstruct the
%                            full output history, not just the raw
%                            physics state:
%                              .t, .X, .k, .nsteps            (as before)
%                              .max_retraction, .total_retracted
%                              .max_tau_act_force, .max_tau_act_moment
%                                (only if opts.track_actuator; carried
%                                forward across resume so a crash doesn't
%                                hide a larger pre-checkpoint peak)
%                              .t_final_target, .h, .store_stride, .params,
%                              .sat_cfg, .cfg
%                                (the EXACT config this run was launched
%                                with -- resume_projected_rk4_run.m
%                                hard-fails on any t_final/h/params/
%                                sat_cfg/cfg mismatch, so an accidental
%                                config change can't silently produce a
%                                hybrid trajectory. store_stride is reused
%                                by default on resume so the stitched
%                                output does NOT have the ~4x-density-jump
%                                bug a round-2 acceptance test caught
%                                before this fix (recomputing a fresh
%                                stride for the remaining steps, ignoring
%                                what the pre-crash run had been using).
%                                NOTE (round-3 audit, precision correction):
%                                this reuse gives the same store_stride on
%                                both sides of a resume boundary, NOT a
%                                strictly uniform sample grid -- resume.t
%                                is always stored as the first sample of a
%                                resumed segment regardless of whether it
%                                falls on a "step mod store_stride==0"
%                                boundary, so one extra off-grid sample is
%                                possible at each resume boundary. Harmless
%                                for plotting/physics (the sample is a
%                                genuine, correctly-computed state, just
%                                not evenly spaced from its neighbors) but
%                                do not read "reused store_stride" as a
%                                stronger uniformity guarantee than that.
%                              .git_sha, .git_dirty, .git_available
%                                (git HEAD commit SHA and working-tree
%                                dirty state at checkpoint time --
%                                resume_projected_rk4_run.m refuses to
%                                resume on a SHA mismatch, and refuses to
%                                LAUNCH a fresh checkpointed run from a
%                                dirty tree by default, since round 2's
%                                config-struct binding alone can't detect
%                                a source-code change that leaves every
%                                config struct byte-identical)
%                              .t_hist_partial, .X_hist_partial
%                                (the FULL decimated output from t=0 up to
%                                this checkpoint -- round 3 follow-up fix:
%                                a resumed call now seeds its own
%                                t_hot/X_hot with whatever prefix IT was
%                                given, so this is never just "since the
%                                last resume" -- a checkpoint written
%                                after N chained resumes still carries the
%                                complete [0,t] history, so a crash at any
%                                point in a resume chain never loses data)
%     .checkpoint_path    : path for the above (default
%                            'projected_rk4_checkpoint.mat').
%     .resume             : OPTIONAL struct in the exact shape saved to a
%                            checkpoint (see above) -- when given, X0 is
%                            ignored and integration continues from
%                            (resume.t, resume.X) at step index
%                            resume.k+1, running through to the SAME
%                            t_hot_final/h as if the whole [0, t_hot_final]
%                            horizon were run in one call. Since RK4 is a
%                            one-step method (no path memory beyond the
%                            current state), the resumed trajectory is
%                            bit-identical (to floating-point roundoff) to
%                            an uninterrupted run -- verified by
%                            diagnose_stepC0b_checkpoint_resume_equivalence.m.
%                            This function itself does NOT validate that
%                            t_hot_final/h/params/sat_cfg/cfg match what
%                            the checkpoint was originally launched with
%                            (that's resume_projected_rk4_run.m's job, the
%                            production-facing entry point -- calling this
%                            function directly with a mismatched resume
%                            struct is a low-level footgun by design, kept
%                            here only for diagnostic scripts that need
%                            it). Round 3 follow-up fix: if resume.t_hist_
%                            partial/X_hist_partial are present, the
%                            returned t_hot/X_hot cover the FULL history
%                            from t=0 (the inherited prefix plus the new
%                            segment), not just the new segment -- this is
%                            what makes chained resumes (crash, resume,
%                            crash again, resume again, ...) never lose
%                            data. If the resume struct has no
%                            t_hist_partial (e.g. an old-format checkpoint,
%                            or a resume struct built by hand for a
%                            diagnostic), the return is just the new
%                            segment as before.
%     .max_steps          : OPTIONAL test hook (diagnostic use only) --
%                            stop the loop after this many total steps
%                            instead of running to nsteps, simulating a
%                            mid-run interruption/crash for acceptance
%                            testing (see
%                            diagnose_stepC0b_checkpoint_resume_equivalence.m).
%                            nsteps itself (and hence the checkpoint's
%                            .nsteps/.t_final_target) still reflects the
%                            TRUE original t_hot_final target, exactly as
%                            a real crash would leave it.
%     .assert_finite      : if true (default), check isfinite(X) after
%                            every step and error immediately with the
%                            failing step/time if not (cheap, always on
%                            by default -- NaN/Inf at step 500,000 of a
%                            1e6-step run should fail loud at step
%                            500,000, not silently propagate to the end).
%     .track_actuator     : if true (default false -- adds ~1 extra
%                            controller_rl call per AUV per step, ~20%
%                            overhead), recompute tau_act at the
%                            post-step state for all 3 AUVs every step
%                            (not just at decimated output samples) and
%                            track running max|tau_act| SEPARATELY for
%                            force channels (1:3) and moment channels
%                            (4:6), so the 30 Nm rotational limit can
%                            actually be checked, not just the 150N force
%                            limit via a single scalar max.
%
% Outputs:
%   t_hot : column vector of stored time points (length depends on
%           store_stride; always includes the first and last computed
%           sample of THIS call)
%   X_hot : [numel(t_hot) x numState] state history at the stored points
%   stats : struct with step count, max retraction norm, wall time,
%           max|tau_act| per channel group (if track_actuator), and
%           (when opts.resume was used) cumulative retraction stats
%           carried forward from the checkpoint.

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
    if ~isfield(opts, 'resume')
        opts.resume = [];
    end
    if ~isfield(opts, 'assert_finite') || isempty(opts.assert_finite)
        opts.assert_finite = true;
    end
    if ~isfield(opts, 'track_actuator') || isempty(opts.track_actuator)
        opts.track_actuator = false;
    end
    if ~isfield(opts, 'max_steps') || isempty(opts.max_steps)
        opts.max_steps = inf;
    end

    nsteps = ceil(t_hot_final / h);

    if isempty(opts.resume)
        X = X0(:);
        t = 0;
        k_start = 1;
        max_retraction = 0;
        total_retracted = 0;
        max_tau_act_force = 0;
        max_tau_act_moment = 0;
        prefix_t = [];
        prefix_X = [];
    else
        r = opts.resume;
        X = r.X(:);
        t = r.t;
        k_start = r.k + 1;
        max_retraction = r.max_retraction;
        total_retracted = r.total_retracted;
        % Carry forward pre-checkpoint actuator peaks (P1 fix, round 2
        % follow-up audit) -- these fields only exist if the interrupted
        % run had opts.track_actuator=true; default to 0 otherwise (same
        % as a fresh start) rather than erroring, since track_actuator is
        % opt-in.
        if isfield(r, 'max_tau_act_force') && ~isempty(r.max_tau_act_force)
            max_tau_act_force = r.max_tau_act_force;
        else
            max_tau_act_force = 0;
        end
        if isfield(r, 'max_tau_act_moment') && ~isempty(r.max_tau_act_moment)
            max_tau_act_moment = r.max_tau_act_moment;
        else
            max_tau_act_moment = 0;
        end
        % Round-3 follow-up audit (P0): carry the INHERITED history prefix
        % into THIS call's own t_hot/X_hot, not just into the caller's
        % post-hoc stitch. Without this, a checkpoint written DURING a
        % resumed call only ever contained that call's own new segment
        % (t_hot/X_hot started fresh at resume.t) -- so a second crash,
        % resumed from THAT checkpoint, would return [t1,t_final] with the
        % original [0,t1] prefix silently gone. Seeding it here means
        % EVERY checkpoint (and the final return value) always carries the
        % complete history back to t=0, no matter how many times a run has
        % been interrupted and resumed. Verified for a two-interruption
        % chain by diagnose_stepC0c_multi_resume_equivalence.m.
        if isfield(r, 't_hist_partial') && ~isempty(r.t_hist_partial)
            prefix_t = r.t_hist_partial(:);
            prefix_X = r.X_hist_partial;
        else
            prefix_t = [];
            prefix_X = [];
        end
    end

    n_prefix = numel(prefix_t);
    n_store_cap = n_prefix + floor(nsteps / opts.store_stride) + 2; % +2: first slot and a safety slot for a non-aligned final step

    t_hot = zeros(n_store_cap, 1);
    X_hot = zeros(n_store_cap, numel(X(:)));

    if n_prefix > 0
        t_hot(1:n_prefix) = prefix_t;
        X_hot(1:n_prefix, :) = prefix_X;
        store_idx = n_prefix;
        % Avoid a duplicate sample if the inherited prefix's last entry is
        % already exactly resume.t (the common case when store_stride=1 or
        % the checkpoint boundary happened to land on a stored sample).
        if abs(prefix_t(end) - t) > 1e-9
            store_idx = store_idx + 1;
            t_hot(store_idx) = t;
            X_hot(store_idx, :) = X.';
        end
    else
        store_idx = 1;
        t_hot(1) = t;
        X_hot(1,:) = X.';
    end

    last_checkpoint_t = t;
    k_end = min(nsteps, k_start - 1 + opts.max_steps);

    tic;
    for k = k_start:k_end

        hk = min(h, t_hot_final - t);

        [Xnext, step_info] = local_projected_rk4_step(t, X, hk, params, sat_cfg, cfg);

        X = Xnext;
        t = t + hk;

        if opts.assert_finite
            assert(all(isfinite(X)), ...
                'projected_rk4_integrate: NaN/Inf in state X at step %d/%d, t=%.6f', k, nsteps, t);
        end

        max_retraction = max(max_retraction, step_info.max_correction);
        total_retracted = total_retracted + step_info.n_retracted;

        if opts.track_actuator
            [tau_f, tau_m] = local_actuator_channel_max(t, X, params, sat_cfg, cfg);
            max_tau_act_force = max(max_tau_act_force, tau_f);
            max_tau_act_moment = max(max_tau_act_moment, tau_m);
        end

        if mod(k, opts.store_stride) == 0 || k == nsteps
            store_idx = store_idx + 1;
            t_hot(store_idx) = t;
            X_hot(store_idx,:) = X.';
        end

        if opts.checkpoint_every_sec > 0 && (t - last_checkpoint_t) >= opts.checkpoint_every_sec
            last_checkpoint_t = t;
            git_fp = git_fingerprint();
            checkpoint = struct('t', t, 'X', X, 'k', k, 'nsteps', nsteps, ...
                'max_retraction', max_retraction, 'total_retracted', total_retracted, ...
                't_final_target', t_hot_final, 'h', h, 'store_stride', opts.store_stride, ...
                'params', params, 'sat_cfg', sat_cfg, 'cfg', cfg, ...
                'git_sha', git_fp.sha, 'git_dirty', git_fp.dirty, 'git_available', git_fp.available, ...
                't_hist_partial', t_hot(1:store_idx), 'X_hist_partial', X_hot(1:store_idx,:));
            if opts.track_actuator
                checkpoint.max_tau_act_force = max_tau_act_force;
                checkpoint.max_tau_act_moment = max_tau_act_moment;
            end
            local_save_checkpoint_atomic(opts.checkpoint_path, checkpoint);
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
    if opts.track_actuator
        stats.max_tau_act_force = max_tau_act_force;
        stats.max_tau_act_moment = max_tau_act_moment;
    end
end


function local_save_checkpoint_atomic(path, checkpoint)
% Write-to-temp-then-rename so a kill during save() cannot leave a
% corrupt/truncated checkpoint file behind (P0 fix, Phase C.0 gate
% follow-up audit).
    tmp_path = [path '.tmp'];
    save(tmp_path, 'checkpoint');
    [ok, msg] = movefile(tmp_path, path, 'f');
    if ~ok
        error('projected_rk4_integrate: atomic checkpoint rename failed: %s', msg);
    end
end


function [max_force, max_moment] = local_actuator_channel_max(t, X, params, sat_cfg, cfg)
% Recomputes tau_act for all 3 AUVs at the given (t, X) and returns the
% max|tau_act| separately for force channels (1:3) and moment channels
% (4:6), so the 30 Nm rotational saturation limit is actually observable
% online (not just the 150N force limit collapsed into one scalar).
    [eta_mat, nu_mat, omega_mat, Wa_cell, ~] = unpack_states(X, cfg);
    max_force = 0;
    max_moment = 0;
    for i = 1:3
        eta = eta_mat(:, i);
        J = jacobian_J(eta);
        eta_dot = J * nu_mat(:, i);
        tau_cmd = controller_rl(eta, eta_dot, t, i, omega_mat(:, i), Wa_cell{i}, params, cfg);
        tau_act = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
        max_force = max(max_force, max(abs(tau_act(1:3))));
        max_moment = max(max_moment, max(abs(tau_act(4:6))));
    end
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
