function manifest = run_phase_c_production(t_final, h, n_target, allow_dirty_launch, results_dir)
% RUN_PHASE_C_PRODUCTION Durable run-and-save wrapper for the full Phase C
% production simulation.
%
% Phase C.0 gate round 6 close-out (GPT audit,
% REVIEW_GPT_2026-08-17_R6.md): checkpoint/resume/git-binding was
% declared CLOSED, but exp4_rl_pts_mc_projected.m returns `res` to the
% MATLAB workspace and never persists it -- for a ~2.4hr run, relying on
% an interactive workspace variable surviving until someone manually
% calls save() is not a sufficient completion contract. A MATLAB/session
% failure after integration finishes but before that manual save would
% lose the entire final artifact (the periodic checkpoint reduces
% RECOVERY cost during the run, but does not replace a named final
% dataset). This wrapper closes that gap:
%   1. Asserts/prints the clean launch fingerprint and parameters (fails
%      closed on unavailable/dirty, same policy as
%      exp4_rl_pts_mc_projected.m's own guard -- this is a second,
%      redundant check at the orchestration level, not a replacement).
%   2. Calls exp4_rl_pts_mc_projected with the exact production args.
%   3. Saves the result to a DETERMINISTIC path via temp-file + atomic
%      rename (movefile), same pattern as the integrator's own
%      checkpoint writes -- a kill mid-save cannot corrupt/truncate a
%      previously-saved result.
%   4. Saves a compact manifest (SHA, dirty state, params/sat_cfg/cfg,
%      start/end wall-clock time, elapsed seconds, stored sample count,
%      online actuator/retraction statistics) alongside it.
%   5. Reloads and VERIFIES the saved artifact afterward: finite states,
%      correct horizon [0,t_final], correct final timestamp, matching
%      sample count -- catches a corrupted/incomplete save immediately,
%      not whenever someone next happens to open the file.
%
% Results land in <repo_root>/phase_c_results/ (gitignored -- see
% .gitignore) -- durable on disk, but NOT tracked, so `git status` stays
% clean for the git-fingerprint checks throughout the run (the exact
% lesson from the round 5/6 clean-tree-evidence work: a tracked diary/
% output file dirties the tree via its own write, before the fingerprint
% is even sampled). Review and selectively copy/commit specific files
% (e.g. just the manifest) after the run, if wanted -- do not commit the
% full trajectory .mat by default (large, and not needed in git history;
% the manifest + this script fully describe how to reproduce it).
%
% Per GPT's explicit instruction: do NOT use allow_dirty_launch=true as
% the resolution for a real Phase C launch -- it exists only for
% deliberate diagnostic/dev runs, same as in exp4_rl_pts_mc_projected.m.

    if nargin < 1 || isempty(t_final)
        t_final = 100.0;
    end
    if nargin < 2 || isempty(h)
        h = 1e-4;
    end
    if nargin < 3 || isempty(n_target)
        n_target = 1001;
    end
    if nargin < 4 || isempty(allow_dirty_launch)
        allow_dirty_launch = false;
    end
    if nargin < 5 || isempty(results_dir)
        repo_root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % .../paper1608/simulation -> .../paper1608 -> repo root
        results_dir = fullfile(repo_root, 'phase_c_results');
    end
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end

    launch_fp = git_fingerprint();
    fprintf('run_phase_c_production: launch fingerprint: available=%d sha=%s dirty=%d\n', ...
        launch_fp.available, launch_fp.sha, launch_fp.dirty);
    if ~launch_fp.available && ~allow_dirty_launch
        error(['run_phase_c_production: git fingerprint UNAVAILABLE -- refusing to launch. ' ...
               'Pass allow_dirty_launch=true only for a deliberate diagnostic/dev run.']);
    elseif launch_fp.dirty && ~allow_dirty_launch
        error(['run_phase_c_production: refusing to launch from a DIRTY git tree. ' ...
               'Commit your changes first, or pass allow_dirty_launch=true only for a deliberate diagnostic/dev run.']);
    end

    params = simulation_params();
    sat_cfg = saturation_config();
    cfg = nn_config();

    fprintf('run_phase_c_production: t_final=%.4f h=%.2e n_target=%d results_dir=%s\n', ...
        t_final, h, n_target, results_dir);
    fprintf('run_phase_c_production: params.inverse_lambda_mode=%s params.inverse_lambda_eps=%.1e params.critic_reward_tau_mode=%s\n', ...
        params.inverse_lambda_mode, params.inverse_lambda_eps, params.critic_reward_tau_mode);

    start_time = datetime('now');
    res = exp4_rl_pts_mc_projected(t_final, h, params, sat_cfg, cfg, n_target, allow_dirty_launch);
    end_time = datetime('now');

    manifest = struct();
    manifest.git_sha = launch_fp.sha;
    manifest.git_dirty = launch_fp.dirty;
    manifest.git_available = launch_fp.available;
    manifest.t_final = t_final;
    manifest.h = h;
    manifest.n_target = n_target;
    manifest.params = params;
    manifest.sat_cfg = sat_cfg;
    manifest.cfg = cfg;
    manifest.start_time = char(start_time);
    manifest.end_time = char(end_time);
    manifest.elapsed_wall_sec = res.stats.elapsed;
    manifest.nsteps = res.stats.nsteps;
    manifest.stored_sample_count = numel(res.t);
    manifest.max_retraction = res.stats.max_retraction;
    manifest.total_retracted = res.stats.total_retracted;
    if isfield(res.stats, 'max_tau_act_force')
        manifest.max_tau_act_force = res.stats.max_tau_act_force;
        manifest.max_tau_act_moment = res.stats.max_tau_act_moment;
    end

    result_path = fullfile(results_dir, 'phase_c_result.mat');
    manifest_path = fullfile(results_dir, 'phase_c_manifest.mat');

    local_save_atomic(result_path, 'res', res);
    local_save_atomic(manifest_path, 'manifest', manifest);

    fprintf('run_phase_c_production: saved result to %s\n', result_path);
    fprintf('run_phase_c_production: saved manifest to %s\n', manifest_path);

    % Verify the saved artifact immediately, not whenever someone next
    % happens to open it.
    d = load(result_path);
    assert(isfield(d, 'res'), 'run_phase_c_production: VERIFY FAILED -- saved file missing the res variable');
    assert(all(isfinite(d.res.X(:))), 'run_phase_c_production: VERIFY FAILED -- non-finite values in the saved result');
    assert(abs(d.res.t(1) - 0) < 1e-9, 'run_phase_c_production: VERIFY FAILED -- saved trajectory does not start at t=0');
    assert(abs(d.res.t(end) - t_final) < 1e-6, ...
        'run_phase_c_production: VERIFY FAILED -- saved trajectory does not reach t_final=%.4f (got %.4f)', t_final, d.res.t(end));
    assert(numel(d.res.t) == manifest.stored_sample_count, 'run_phase_c_production: VERIFY FAILED -- reloaded sample count mismatch');
    fprintf('run_phase_c_production: VERIFIED -- reloaded artifact is finite, covers [0,%.4f], %d samples.\n', t_final, numel(d.res.t));

    fprintf('run_phase_c_production: DONE. wall time %.1f min.\n', manifest.elapsed_wall_sec/60);
end


function local_save_atomic(path, varname, value)
    tmp_path = [path '.tmp'];
    S = struct();
    S.(varname) = value;
    save(tmp_path, '-struct', 'S');
    [ok, msg] = movefile(tmp_path, path, 'f');
    if ~ok
        error('run_phase_c_production: atomic save rename failed for %s: %s', path, msg);
    end
end
