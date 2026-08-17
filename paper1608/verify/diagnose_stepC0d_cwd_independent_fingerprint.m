function diagnose_stepC0d_cwd_independent_fingerprint()
    % DIAGNOSE_STEPC0D_CWD_INDEPENDENT_FINGERPRINT
    % Phase C.0 gate round-4 follow-up (P0, fourth GPT audit pass):
    % git_fingerprint.m used to call plain `git rev-parse HEAD`, which
    % resolves relative to MATLAB's current working directory -- launched
    % from outside this repo (or from inside a DIFFERENT git repo), it
    % would report "unavailable" or, worse, silently return the WRONG
    % repo's SHA. This proves the anchored fix (git -C <this file's own
    % directory>) is actually CWD-independent, per GPT's exact request:
    % change CWD to a non-repository temp directory and confirm the
    % helper still returns the Paper 1608 repo's SHA.

    addpath(genpath('paper1608'));

    original_cwd = pwd();
    fp_from_repo_cwd = git_fingerprint();
    fprintf('From repo CWD (%s): available=%d, sha=%s, dirty=%d\n', ...
        original_cwd, fp_from_repo_cwd.available, fp_from_repo_cwd.sha, fp_from_repo_cwd.dirty);
    assert(fp_from_repo_cwd.available, 'FAIL: git_fingerprint unavailable even from the repo''s own CWD -- cannot proceed with this test');

    temp_dir = tempname(); % a path guaranteed not to exist yet, and not inside this repo
    mkdir(temp_dir);
    cleanup_obj = onCleanup(@() local_cleanup(original_cwd, temp_dir)); %#ok<NASGU>

    try
        cd(temp_dir);
        fprintf('Changed CWD to non-repository temp dir: %s\n', pwd());

        assert(isempty(strfind(lower(pwd()), lower('1608 simulation'))), ...
            'test setup error: temp dir unexpectedly looks like it could be inside the repo'); %#ok<STRIFCND>

        fp_from_temp_cwd = git_fingerprint();
        fprintf('From non-repo CWD: available=%d, sha=%s, dirty=%d, repo_root=%s\n', ...
            fp_from_temp_cwd.available, fp_from_temp_cwd.sha, fp_from_temp_cwd.dirty, fp_from_temp_cwd.repo_root);

        assert(fp_from_temp_cwd.available, ...
            'FAIL: git_fingerprint reported unavailable when called from a non-repository CWD -- anchoring did not work');
        assert(strcmp(fp_from_temp_cwd.sha, fp_from_repo_cwd.sha), ...
            'FAIL: SHA from non-repo CWD (%s) does not match SHA from repo CWD (%s) -- fingerprint is CWD-dependent', ...
            fp_from_temp_cwd.sha, fp_from_repo_cwd.sha);
        assert(fp_from_temp_cwd.dirty == fp_from_repo_cwd.dirty, ...
            'FAIL: dirty-state from non-repo CWD does not match repo CWD -- fingerprint is CWD-dependent');

        fprintf('\nPASS: git_fingerprint() returns the SAME Paper 1608 repo SHA/dirty-state regardless of MATLAB''s current working directory.\n');
    catch ME
        cd(original_cwd);
        rethrow(ME);
    end

    cd(original_cwd);
    fprintf('=== END C.0d (CWD-independent git fingerprint CONFIRMED) ===\n');
end

function local_cleanup(original_cwd, temp_dir)
    try
        cd(original_cwd);
    catch
    end
    try
        if exist(temp_dir, 'dir')
            rmdir(temp_dir, 's');
        end
    catch
    end
end
