function res = resume_projected_rk4_run(checkpoint_path, t_final, h, params, sat_cfg, cfg, store_stride_override, force_mismatch)
% RESUME_PROJECTED_RK4_RUN Continue a production run from a saved checkpoint.
%
% Phase C.0 gate follow-up (P0 findings from BOTH GPT audit rounds):
%   Round 1: the original checkpoint was a diagnostic snapshot only, not
%   usable to actually continue a crashed run.
%   Round 2: the round-1 fix's own acceptance test (diagnose_stepC0b_*)
%   exercised the raw integrator's resume path directly, not this
%   wrapper, and used a checkpoint whose .nsteps reflected a DIFFERENT
%   (shorter) target than the eventual resume -- exactly the mismatch
%   this wrapper is supposed to catch, so round 1's test would not have
%   caught a real bug here. Round 2 also found: (a) nothing bound a
%   checkpoint to the params/h/t_final it was produced under, so an
%   accidental config change on resume could silently produce a hybrid,
%   invalid trajectory; (b) a resumed run had no way to reconstruct the
%   pre-crash decimated output history needed for Phase C figures, only
%   the post-resume tail segment.
%
% This version fixes both, PLUS a third bug the round-2 acceptance test
% (rewritten to actually exercise this wrapper) caught during its own
% first run: resuming used to always recompute a FRESH store_stride
% targeting ~1001 samples for the remaining steps, regardless of what
% stride the pre-crash run was actually using -- producing a stitched
% history with a jarring density discontinuity right at the resume
% boundary (e.g. dense pre-crash samples, then suddenly 4x-sparser
% post-resume samples). Fixed: the checkpoint now records
% .store_stride, and resume reuses it BY DEFAULT so the stitched output
% has uniform density throughout; pass store_stride_override explicitly
% only if you deliberately want a different density for the remaining
% segment (falls back to old checkpoints without a saved store_stride
% too, via a 1001-sample-target heuristic, with a warning).
%
%   - HARD-FAILS unless the checkpoint's saved t_final_target/h/params/
%     sat_cfg/cfg exactly match (via isequal) what's passed here, unless
%     force_mismatch=true is passed explicitly (diagnostic override only
%     -- never use this for a real production resume).
%   - Returns the FULL stitched [0, t_final] history (checkpoint's
%     persisted t_hist_partial/X_hist_partial concatenated with the new
%     resumed segment, with the shared boundary sample de-duplicated if
%     present), not just the tail.
%
% Equivalence to an uninterrupted run -- using this exact wrapper, with a
% checkpoint produced by a run whose ORIGINAL target matches the resume
% target (i.e. an artificially-interrupted single run, not two runs with
% different targets) -- is verified by
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

    if ~isempty(mismatches) && ~force_mismatch
        error(['resume_projected_rk4_run: checkpoint config does NOT match the requested resume config -- ' ...
               'refusing to resume (would silently produce a hybrid, invalid trajectory). Mismatches:\n  %s\n' ...
               'Pass force_mismatch=true only for deliberate diagnostic testing, never for a real production resume.'], ...
              strjoin(mismatches, '\n  '));
    elseif ~isempty(mismatches) && force_mismatch
        warning('resume_projected_rk4_run: FORCING resume despite config mismatch(es):\n  %s', strjoin(mismatches, '\n  '));
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
    opts.checkpoint_every_sec = 10;
    opts.checkpoint_path = checkpoint_path;
    opts.resume = checkpoint;
    opts.assert_finite = true;
    opts.track_actuator = isfield(checkpoint, 'max_tau_act_force');

    [t_seg, X_seg, stats] = projected_rk4_integrate(t_final, h, checkpoint.X, params, sat_cfg, cfg, opts);

    fprintf('resume_projected_rk4_run: resumed segment [%.4f, %.4f], %d new samples\n', ...
        checkpoint.t, t_seg(end), numel(t_seg));

    % Stitch the pre-crash persisted history (if present) with the new
    % segment into one monotone, non-duplicated history (P0 fix, round 2).
    if isfield(checkpoint, 't_hist_partial') && isfield(checkpoint, 'X_hist_partial') ...
            && ~isempty(checkpoint.t_hist_partial)
        [t_full, X_full] = local_stitch(checkpoint.t_hist_partial(:), checkpoint.X_hist_partial, t_seg, X_seg);
        fprintf('resume_projected_rk4_run: stitched with %d pre-checkpoint samples -> %d total samples covering [0, %.4f]\n', ...
            numel(checkpoint.t_hist_partial), numel(t_full), t_full(end));
    else
        warning(['resume_projected_rk4_run: checkpoint has no persisted pre-crash history ' ...
                 '(t_hist_partial/X_hist_partial) -- returning ONLY the resumed tail segment ' ...
                 '[%.4f, %.4f]. This checkpoint predates the round-2 history-persistence fix.'], ...
                checkpoint.t, t_seg(end));
        t_full = t_seg;
        X_full = X_seg;
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

function [full_t, full_X] = local_stitch(hist_t, hist_X, seg_t, seg_X)
    if ~isempty(hist_t) && abs(hist_t(end) - seg_t(1)) < 1e-9
        full_t = [hist_t(1:end-1); seg_t];
        full_X = [hist_X(1:end-1, :); seg_X];
    else
        full_t = [hist_t; seg_t];
        full_X = [hist_X; seg_X];
    end
end
