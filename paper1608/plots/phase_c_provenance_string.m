function s = phase_c_provenance_string(manifest, params)
    % PHASE_C_PROVENANCE_STRING
    % One-line dataset provenance string (git SHA, inverse-lambda epsilon)
    % for figure captions, per REVIEW_GPT_2026-08-17_R8/R9's condition #4:
    % "preserve the dataset's provenance SHA and fixed epsilon in figure
    % metadata/captions".

    sha = manifest.git_sha;
    if numel(sha) > 10
        sha = sha(1:10);
    end
    s = sprintf('dataset: t_final=%.0fs, git %s (dirty=%d), inverse_lambda_eps=%.0e', ...
        manifest.t_final, sha, manifest.git_dirty, params.inverse_lambda_eps);
end
