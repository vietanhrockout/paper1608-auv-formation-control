function fp = git_fingerprint()
% GIT_FINGERPRINT Returns the current git HEAD commit SHA and whether the
% working tree is dirty (uncommitted changes), for the Paper 1608 REPO
% SPECIFICALLY -- not whatever repo (if any) happens to contain MATLAB's
% current working directory.
%
% Phase C.0 gate round 3 follow-up (P0, GPT audit): checkpoints need to
% be bound to the exact source-code state, not just the parameter/config
% state, since a source change between crash and resume that leaves every
% config struct byte-identical would otherwise silently produce a hybrid
% trajectory. Shared by projected_rk4_integrate.m (records it in every
% checkpoint) and resume_projected_rk4_run.m (compares it on resume, and
% refuses a fresh checkpointed production launch from a dirty tree).
%
% Round 4 follow-up (P0, GPT audit): the original version ran plain
% `git rev-parse HEAD` / `git status --porcelain`, which resolve relative
% to MATLAB's CURRENT WORKING DIRECTORY, not this file's location. Launch
% MATLAB (or just `cd`) somewhere else -- a parent directory, an unrelated
% Git repo, anywhere outside this repo -- and the fingerprint would either
% report "unavailable" or, worse, silently record the WRONG repository's
% SHA. Fixed: anchor every git invocation to THIS file's own directory
% (which is inside the Paper 1608 repo by construction, `git -C` accepts
% any subdirectory, not just the root) via mfilename('fullpath'), so the
% result is independent of the caller's CWD. Verified by
% paper1608/verify/diagnose_stepC0d_cwd_independent_fingerprint.m, which
% changes CWD to a non-repository temp directory and confirms the SHA is
% unchanged.
%
% Degrades gracefully (fp.available=false) rather than erroring if git or
% a repo isn't available -- e.g. this code copied somewhere without its
% .git directory. Callers should treat fp.available=false as "cannot
% verify" (warn, don't silently trust) -- and for anything checkpointed in
% production, FAIL CLOSED (refuse to proceed) rather than continue
% unverified; that policy lives in the callers
% (exp4_rl_pts_mc_projected.m, resume_projected_rk4_run.m), not here.

    fp = struct('sha', 'unknown', 'dirty', true, 'available', false, 'repo_root', '');

    try
        this_file_dir = fileparts(mfilename('fullpath')); % .../paper1608/simulation
        repo_root = fileparts(fileparts(this_file_dir));   % .../paper1608 -> repo root
        fp.repo_root = repo_root;

        cmd_sha = sprintf('git -C "%s" rev-parse HEAD', repo_root);
        cmd_dirty = sprintf('git -C "%s" status --porcelain', repo_root);

        [status_sha, out_sha] = system(cmd_sha);
        [status_dirty, out_dirty] = system(cmd_dirty);
        if status_sha == 0
            fp.sha = strtrim(out_sha);
            fp.available = true;
            fp.dirty = (status_dirty == 0) && ~isempty(strtrim(out_dirty));
        end
    catch
        % leave fp at its unavailable/dirty=true default
    end
end
