function diagnose_stepR10_retraction_reconciliation()
    % DIAGNOSE_STEPR10_RETRACTION_RECONCILIATION
    % Read-only diagnostic requested by REVIEW_GPT_2026-08-17_R10.md (P1
    % evidence): make the total_retracted "freeze" reconciliation
    % independently auditable from the pushed repository, not just a
    % claim in prose. For each of the three source artifacts (t=15s
    % Phase B.3 result, an intermediate t=90.0003s Phase C checkpoint,
    % and the t=100s Phase C final manifest), records the artifact
    % filename, its SHA-256 hash, simulated time/step count,
    % total_retracted/max_retraction at full precision, and
    % max_tau_act_moment (the field used to prove the checkpoint is a
    % live, not frozen/stale, snapshot). Prints an explicit PASS/FAIL
    % comparison. Does not modify any production file.
    %
    % NOTE: the t=90.0003s checkpoint (projected_rk4_checkpoint.mat) is a
    % gitignored, disk-only production artifact from the actual Phase C
    % run and is NOT committed to the repo (per the project's existing
    % checkpoint-tracking design). If it is not present on this machine,
    % this script reports that source as UNAVAILABLE rather than failing
    % silently -- the two committed artifacts (B.3, Phase C final) are
    % still cross-checked against each other.

    fprintf('=== Step R10: total_retracted / max_retraction reconciliation ===\n\n');

    sources = struct('label', {}, 'path', {}, 'present', {});
    sources(1) = struct('label', 't=15s (Phase B.3)', 'path', 'phase_b3_result_t15.mat', 'present', false);
    sources(2) = struct('label', 't=90.0003s (Phase C intermediate checkpoint, gitignored/disk-only)', ...
        'path', 'projected_rk4_checkpoint.mat', 'present', false);
    sources(3) = struct('label', 't=100s (Phase C final manifest)', 'path', 'phase_c_manifest_t100.mat', 'present', false);

    rows = struct('label', {}, 'path', {}, 'sha256', {}, 't', {}, 'nsteps', {}, ...
        'total_retracted', {}, 'max_retraction', {}, 'max_tau_act_moment', {});

    for k = 1:numel(sources)
        src = sources(k);
        if ~exist(src.path, 'file')
            fprintf('[%d] %-70s -- UNAVAILABLE (not present on this machine)\n', k, src.label);
            continue;
        end

        sha = local_sha256(src.path);
        [t_val, nsteps_val, total_retracted_val, max_retraction_val, max_tau_act_moment_val] = ...
            local_extract_fields(src.path);

        rows(end + 1) = struct('label', src.label, 'path', src.path, 'sha256', sha, ...
            't', t_val, 'nsteps', nsteps_val, 'total_retracted', total_retracted_val, ...
            'max_retraction', max_retraction_val, 'max_tau_act_moment', max_tau_act_moment_val); %#ok<AGROW>

        fprintf('[%d] %s\n', k, src.label);
        fprintf('    file: %s\n', src.path);
        fprintf('    sha256: %s\n', sha);
        fprintf('    t=%.6f  nsteps=%d\n', t_val, nsteps_val);
        fprintf('    total_retracted=%d  max_retraction=%.10e\n', total_retracted_val, max_retraction_val);
        fprintf('    max_tau_act_moment=%.10f\n\n', max_tau_act_moment_val);
    end

    fprintf('=== Comparison ===\n');
    if numel(rows) < 2
        fprintf('FAIL: fewer than 2 sources available -- cannot cross-check.\n');
        return;
    end

    tr_vals = [rows.total_retracted];
    mr_vals = [rows.max_retraction];
    tau_vals = [rows.max_tau_act_moment];
    tau_recorded_mask = ~isnan(tau_vals); % Phase B.3's res.stats has no actuator tracking

    tr_match = all(tr_vals == tr_vals(1));
    mr_match = all(mr_vals == mr_vals(1));
    tau_recorded = tau_vals(tau_recorded_mask);
    tau_has_2plus = numel(tau_recorded) >= 2;
    if tau_has_2plus
        tau_all_equal = all(tau_recorded == tau_recorded(1));
    else
        tau_all_equal = true; % cannot demonstrate variation with <2 recorded values
    end

    fprintf('total_retracted identical across all %d available sources: %s (%s)\n', ...
        numel(rows), local_bool_str(tr_match), mat2str(tr_vals));
    fprintf('max_retraction identical across all %d available sources: %s (%s)\n', ...
        numel(rows), local_bool_str(mr_match), mat2str(mr_vals, 12));
    fprintf('max_tau_act_moment recorded in %d/%d sources (Phase B.3''s res.stats has no actuator tracking): %s\n', ...
        nnz(tau_recorded_mask), numel(rows), mat2str(tau_recorded, 8));
    fprintf('max_tau_act_moment VARIES among sources where recorded (proves live, not frozen, snapshots): %s\n', ...
        local_bool_str(tau_has_2plus && ~tau_all_equal));

    fprintf('\nVERDICT: ');
    if tr_match && mr_match && tau_has_2plus && ~tau_all_equal
        fprintf(['PASS -- total_retracted/max_retraction are byte-identical across all available\n' ...
            'time points while max_tau_act_moment progresses between the sources where it is\n' ...
            'recorded, confirming a genuine counter freeze (not a copy-paste artifact and not a\n' ...
            'frozen/stale checkpoint).\n']);
    else
        fprintf('FAIL -- reconciliation does not hold with the currently available sources.\n');
    end
end

function s = local_bool_str(b)
    if b
        s = 'YES';
    else
        s = 'NO';
    end
end

function sha = local_sha256(path)
    md = java.security.MessageDigest.getInstance('SHA-256');
    fid = fopen(path, 'rb');
    cleanupObj = onCleanup(@() fclose(fid));
    chunk = fread(fid, 1024 * 1024, '*uint8');
    while ~isempty(chunk)
        md.update(chunk);
        chunk = fread(fid, 1024 * 1024, '*uint8');
    end
    digest = typecast(md.digest(), 'uint8');
    sha = lower(sprintf('%02x', digest));
end

function [t_val, nsteps_val, total_retracted_val, max_retraction_val, max_tau_act_moment_val] = ...
        local_extract_fields(path)
    d = load(path);
    if isfield(d, 'checkpoint')
        c = d.checkpoint;
        t_val = c.t;
        nsteps_val = c.k;
        total_retracted_val = c.total_retracted;
        max_retraction_val = c.max_retraction;
        max_tau_act_moment_val = c.max_tau_act_moment;
    elseif isfield(d, 'manifest')
        m = d.manifest;
        t_val = m.t_final;
        nsteps_val = m.nsteps;
        total_retracted_val = m.total_retracted;
        max_retraction_val = m.max_retraction;
        max_tau_act_moment_val = m.max_tau_act_moment;
    elseif isfield(d, 'res') && isfield(d.res, 'stats')
        r = d.res;
        t_val = r.t(end);
        nsteps_val = r.stats.nsteps;
        total_retracted_val = r.stats.total_retracted;
        max_retraction_val = r.stats.max_retraction;
        if isfield(r.stats, 'max_tau_act_moment')
            max_tau_act_moment_val = r.stats.max_tau_act_moment;
        else
            max_tau_act_moment_val = NaN;
        end
    else
        error('local_extract_fields: unrecognized artifact structure in %s', path);
    end
end
