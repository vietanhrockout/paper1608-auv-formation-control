function res = resume_projected_rk4_run(checkpoint_path, t_final, h, params, sat_cfg, cfg, n_target)
% RESUME_PROJECTED_RK4_RUN Continue a production run from a saved checkpoint.
%
% Phase C.0 gate follow-up (P0 finding: the checkpoint written by
% projected_rk4_integrate.m was a diagnostic snapshot only, not usable to
% actually continue a crashed run through the production entry point).
%
% This loads a checkpoint written by exp4_rl_pts_mc_projected.m /
% projected_rk4_integrate.m (via opts.checkpoint_every_sec), and continues
% integration from (checkpoint.t, checkpoint.X) through to t_final at step
% size h -- MUST be the same t_final/h as the original run, since nsteps
% is computed from them and the resumed loop continues the SAME step
% index sequence (see projected_rk4_integrate.m's opts.resume docs).
%
% Returns a res struct in the same shape as exp4_rl_pts_mc_projected.m's
% output, but covering ONLY the resumed segment [checkpoint.t, t_final]
% -- NOT the full [0, t_final] history. If you need the full stitched
% trajectory, concatenate res.t/res.X with whatever partial output you
% saved from the pre-crash run yourself; this function does not attempt
% to reconstruct the pre-checkpoint decimated history (only the raw
% physics state needed to continue correctly survives a checkpoint by
% design -- recomputing that history would mean re-running the expensive
% part this function exists to avoid).
%
% Equivalence to an uninterrupted run is verified by
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
    if nargin < 7 || isempty(n_target)
        n_target = 1001;
    end

    if ~exist(checkpoint_path, 'file')
        error('resume_projected_rk4_run: checkpoint file not found: %s', checkpoint_path);
    end
    d = load(checkpoint_path);
    checkpoint = d.checkpoint;

    fprintf('resume_projected_rk4_run: resuming from t=%.4f (step %d/%d) to t_final=%.4f ...\n', ...
        checkpoint.t, checkpoint.k, checkpoint.nsteps, t_final);

    nsteps_total = ceil(t_final / h);
    if nsteps_total ~= checkpoint.nsteps
        error(['resume_projected_rk4_run: t_final/h do not match the checkpoint''s original run ' ...
               '(checkpoint.nsteps=%d, but ceil(t_final/h)=%d for the values passed here). ' ...
               'Resume requires the exact same t_final/h as the interrupted run.'], ...
              checkpoint.nsteps, nsteps_total);
    end

    remaining_steps = nsteps_total - checkpoint.k;
    store_stride = max(1, floor(remaining_steps / n_target));

    opts = struct();
    opts.store_stride = store_stride;
    opts.checkpoint_every_sec = 10;
    opts.checkpoint_path = 'projected_rk4_checkpoint.mat';
    opts.resume = checkpoint;

    [t_seg, X_seg, stats] = projected_rk4_integrate(t_final, h, checkpoint.X, params, sat_cfg, cfg, opts);

    fprintf('resume_projected_rk4_run: done, resumed segment [%.4f, %.4f], %d stored samples\n', ...
        checkpoint.t, t_seg(end), numel(t_seg));

    res = struct();
    res.t = t_seg;
    res.X = X_seg;
    res.params = params;
    res.name = 'Exp4_RL_PT_SMC_Projected_ResumedSegment';
    res.h = h;
    res.stats = stats;
    res.resumed_from_t = checkpoint.t;
end
