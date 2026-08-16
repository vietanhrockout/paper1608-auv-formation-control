function res = resume_projected_rk4_run(checkpoint_path, t_final, h, params, sat_cfg, cfg, store_stride_override, force_mismatch, max_steps, checkpoint_every_sec)
% RESUME_PROJECTED_RK4_RUN Continue a production run from a saved checkpoint.
%
% Phase C.0 gate follow-up (P0 findings across THREE GPT audit rounds):
%   Round 1: the original checkpoint was a diagnostic snapshot only, not
%   usable to actually continue a crashed run.
%   Round 2: round 1's acceptance test exercised the raw integrator's
%   resume path directly, not this wrapper, using a checkpoint whose
%   .nsteps reflected a DIFFERENT (shorter) target than the eventual
%   resume -- exactly the mismatch this wrapper is supposed to catch, so
%   round 1's test would not have caught a real bug here. Round 2 also
%   found: (a) nothing bound a checkpoint to the params/h/t_final it was
%   produced under; (b) a resumed run had no way to reconstruct the
%   pre-crash decimated output history.
%   Round 3: round 2's own fix, tested properly this time, revealed a
%   FOURTH gap: a checkpoint written DURING an already-resumed call only
%   ever contained ITS OWN new segment's history -- so a SECOND crash,
%   resumed from that second checkpoint, would silently lose the
%   original prefix. Also: nothing bound a checkpoint to the actual
%   source-code state (only to config structs), so a source change
%   between crash and resume could silently produce a hybrid trajectory
%   at the code level even with identical params.
%
% This version:
%   - HARD-FAILS unless the checkpoint's saved t_final_target/h/params/
%     sat_cfg/cfg AND git commit SHA exactly match (via isequal /
%     string comparison) what's passed here / the current HEAD, unless
%     force_mismatch=true is passed explicitly (diagnostic override only
%     -- never use this for a real production resume).
%   - WARNS if git isn't available to verify the SHA (can't confirm
%     safety either way) and WARNS if the checkpoint was itself written
%     from a dirty tree (the exact source state at checkpoint time can't
%     be reconstructed from the SHA alone in that case).
%   - Returns the FULL [0, t_final] history directly from
%     projected_rk4_integrate.m, which (as of the round-3 fix) seeds its
%     own output arrays with whatever prefix its opts.resume carries --
%     so this wrapper no longer needs to do its own post-hoc stitching,
%     and the result is correct even across a CHAIN of multiple crashes
%     and resumes, not just a single interruption.
%
% Equivalence to an uninterrupted run across a chain of TWO interruptions
% (not just one) is verified by
% paper1608/verify/diagnose_stepC0c_multi_resume_equivalence.m; the
% original single-interruption case remains covered by
% paper1608/verify/diagnose_stepC0b_checkpoint_resume_equivalence.m.

    if nargin < 4 || isempty(params)
        params = simulation_params();
    end
    if nargin < 5 || isempty(sat_cfg)
        sat_cfg = saturation_config();
    end
    if nargin < 6 || isempty(cfg)
        cfg = nn_config();
    end
    if nargin < 7
        store_stride_override = [];
    end
    if nargin < 8 || isempty(force_mismatch)
        force_mismatch = false;
    end
    if nargin < 9 || isempty(max_steps)
        max_steps = inf; % TEST HOOK ONLY (diagnose_stepC0c_*): simulate a second interruption mid-resume. Never set in real production use.
    end
    if nargin < 10 || isempty(checkpoint_every_sec)
        checkpoint_every_sec = 10; % production default; override only for short-horizon acceptance tests that need a checkpoint to fire within a small window
    end

    if ~exist(checkpoint_path, 'file')
        error('resume_projected_rk4_run: checkpoint file not found: %s', checkpoint_path);
    end
    d = load(checkpoint_path);
    checkpoint = d.checkpoint;

    required_fields = {'t_final_target', 'h', 'params', 'sat_cfg', 'cfg'};
    missing = required_fields(~isfield(checkpoint, required_fields));
    if ~isempty(missing)
        error(['resume_projected_rk4_run: checkpoint is missing config-binding field(s) [%s] -- ' ...
               'it was written by an older/incompatible version of projected_rk4_integrate.m ' ...
               'and cannot be safely resumed through this wrapper.'], strjoin(missing, ', '));
    end

    mismatches = {};
    if ~isequal(checkpoint.t_final_target, t_final)
        mismatches{end+1} = sprintf('t_final: checkpoint=%.6g vs requested=%.6g', checkpoint.t_final_target, t_final);
    end
    if ~isequal(checkpoint.h, h)
        mismatches{end+1} = sprintf('h: checkpoint=%.6g vs requested=%.6g', checkpoint.h, h);
    end
    if ~isequal(checkpoint.params, params)
        mismatches{end+1} = 'params struct differs (e.g. inverse_lambda_mode/eps, critic_reward_tau_mode, or any Table 1 value)';
    end
    if ~isequal(checkpoint.sat_cfg, sat_cfg)
        mismatches{end+1} = 'sat_cfg struct differs (actuator limits)';
    end
    if ~isequal(checkpoint.cfg, cfg)
        mismatches{end+1} = 'cfg struct differs (NN architecture/bounds)';
    end

    % Round-3 fix: bind to the actual source-code state, not just config
    % structs (a source change between crash and resume could otherwise
    % silently produce a hybrid trajectory even with identical params).
    if isfield(checkpoint, 'git_sha') && isfield(checkpoint, 'git_available')
        current_fp = git_fingerprint();
        if ~current_fp.available || ~checkpoint.git_available
            warning(['resume_projected_rk4_run: git SHA could not be verified for this checkpoint or the ' ...
                     'current tree (git unavailable at checkpoint time and/or now) -- proceeding WITHOUT ' ...
                     'source-code verification. This is a real gap in the safety guarantee, not a pass.']);
        elseif ~strcmp(checkpoint.git_sha, current_fp.sha)
            mismatches{end+1} = sprintf('git commit SHA: checkpoint=%s vs current=%s', checkpoint.git_sha, current_fp.sha);
        end
        if checkpoint.git_available && checkpoint.git_dirty
            warning(['resume_projected_rk4_run: the checkpoint was written from a DIRTY working tree ' ...
                     '(uncommitted changes at checkpoint time) -- the SHA alone does not fully pin down ' ...
                     'the source state that produced it. Treat this run''s reproducibility as compromised.']);
        end
    else
        warning(['resume_projected_rk4_run: checkpoint predates the round-3 git-fingerprint fix -- ' ...
                 'source-code state cannot be verified for this resume.']);
    end

    if ~isempty(mismatches) && ~force_mismatch
        error(['resume_projected_rk4_run: checkpoint config/source does NOT match the requested resume -- ' ...
               'refusing to resume (would silently produce a hybrid, invalid trajectory). Mismatches:\n  %s\n' ...
               'Pass force_mismatch=true only for deliberate diagnostic testing, never for a real production resume.'], ...
              strjoin(mismatches, '\n  '));
    elseif ~isempty(mismatches) && force_mismatch
        warning('resume_projected_rk4_run: FORCING resume despite mismatch(es):\n  %s', strjoin(mismatches, '\n  '));
    end

    fprintf('resume_projected_rk4_run: resuming from t=%.4f (step %d/%d) to t_final=%.4f ...\n', ...
        checkpoint.t, checkpoint.k, checkpoint.nsteps, t_final);

    nsteps_total = ceil(t_final / h);
    if nsteps_total ~= checkpoint.nsteps
        error(['resume_projected_rk4_run: t_final/h imply nsteps=%d, but checkpoint.nsteps=%d. ' ...
               'This should be unreachable given the config checks above already passed -- ' ...
               'investigate before proceeding.'], nsteps_total, checkpoint.nsteps);
    end

    if ~isempty(store_stride_override)
        store_stride = store_stride_override;
    elseif isfield(checkpoint, 'store_stride') && ~isempty(checkpoint.store_stride)
        store_stride = checkpoint.store_stride; % reuse pre-crash density -- avoids the boundary discontinuity bug caught by C0b v2
    else
        warning(['resume_projected_rk4_run: checkpoint has no saved store_stride (predates the round-2 fix) -- ' ...
                 'falling back to a fresh ~1001-sample-target stride for the remaining segment, which will NOT ' ...
                 'match the pre-crash segment''s density (a visible discontinuity at the stitch boundary).']);
        remaining_steps = nsteps_total - checkpoint.k;
        store_stride = max(1, floor(remaining_steps / 1001));
    end

    opts = struct();
    opts.store_stride = store_stride;
    opts.checkpoint_every_sec = checkpoint_every_sec;
    opts.checkpoint_path = checkpoint_path;
    opts.resume = checkpoint;
    opts.assert_finite = true;
    opts.track_actuator = isfield(checkpoint, 'max_tau_act_force');
    opts.max_steps = max_steps;

    % projected_rk4_integrate.m (round-3 fix) seeds its own output with
    % checkpoint.t_hist_partial/X_hist_partial itself now, so t_full/X_full
    % returned here are ALREADY the complete [0,t_final] history -- no
    % separate stitching step needed (and doing one would double-prepend).
    [t_full, X_full, stats] = projected_rk4_integrate(t_final, h, checkpoint.X, params, sat_cfg, cfg, opts);

    if isfield(checkpoint, 't_hist_partial') && ~isempty(checkpoint.t_hist_partial)
        fprintf('resume_projected_rk4_run: resumed and stitched -> %d total samples covering [0, %.4f] (inherited %d pre-checkpoint samples)\n', ...
            numel(t_full), t_full(end), numel(checkpoint.t_hist_partial));
    else
        warning(['resume_projected_rk4_run: checkpoint has no persisted pre-crash history ' ...
                 '(t_hist_partial/X_hist_partial) -- returning ONLY the resumed tail segment ' ...
                 '[%.4f, %.4f]. This checkpoint predates the round-2 history-persistence fix.'], ...
                checkpoint.t, t_full(end));
    end

    res = struct();
    res.t = t_full;
    res.X = X_full;
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC_Projected_Resumed';
    res.h = h;
    res.stats = stats;
    res.resumed_from_t = checkpoint.t;
end
