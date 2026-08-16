function fp = git_fingerprint()
% GIT_FINGERPRINT Returns the current git HEAD commit SHA and whether the
% working tree is dirty (uncommitted changes).
%
% Phase C.0 gate round 3 follow-up (P0, GPT audit): checkpoints need to
% be bound to the exact source-code state, not just the parameter/config
% state, since a source change between crash and resume that leaves every
% config struct byte-identical would otherwise silently produce a hybrid
% trajectory. Shared by projected_rk4_integrate.m (records it in every
% checkpoint) and resume_projected_rk4_run.m (compares it on resume, and
% refuses a fresh checkpointed production launch from a dirty tree).
%
% Degrades gracefully (fp.available=false) rather than erroring if git or
% a repo isn't available -- e.g. this code copied somewhere without its
% .git directory. Callers should treat fp.available=false as "cannot
% verify" (warn, don't silently trust), not as "safe to proceed".

    fp = struct('sha', 'unknown', 'dirty', true, 'available', false);
    try
        [status_sha, out_sha] = system('git rev-parse HEAD');
        [status_dirty, out_dirty] = system('git status --porcelain');
        if status_sha == 0
            fp.sha = strtrim(out_sha);
            fp.available = true;
            fp.dirty = (status_dirty == 0) && ~isempty(strtrim(out_dirty));
        end
    catch
        % leave fp at its unavailable/dirty=true default
    end
end
