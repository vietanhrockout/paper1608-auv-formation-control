function diagnose_stepR8_crossing_times()
    % DIAGNOSE_STEPR8_CROSSING_TIMES
    % Read-only diagnostic requested by REVIEW_GPT_2026-08-17_R8.md (P0):
    % compute, from the full 1003-sample Phase C trajectory, the first
    % entry time and sustained-entry time (never exits again) into
    % explicitly declared thresholds for both E_chi and E_s, rather than
    % inferring crossing behavior from the sparse printed table. Also
    % reports the exact sample values at t=5s (T1*) and t=10s (T1*+T2*)
    % for the record. Does not modify any production file.

    d = load('phase_c_analysis_t100.mat');
    a = d.analysis;
    t = a.t; E_chi = a.E_chi; E_s = a.E_s;

    fprintf('=== Exact-sample values at declared deadlines ===\n');
    print_at(t, E_chi, E_s, 5.0, 'T1*=5s');
    print_at(t, E_chi, E_s, 10.0, 'T1*+T2*=10s');

    fprintf('\n=== First-entry and sustained-entry times ===\n');
    fprintf('(sustained = index i such that E(j) <= thresh for ALL j >= i)\n');
    thresholds_chi = [1.0, 0.1, 0.05, 0.02];
    thresholds_s   = [1.0, 0.1, 0.01];
    for th = thresholds_chi
        report_crossing('E_chi', t, E_chi, th);
    end
    for th = thresholds_s
        report_crossing('E_s', t, E_s, th);
    end

    fprintf('\n=== Post-10s window statistics (declared combined horizon) ===\n');
    mask10 = t >= 10;
    fprintf('max E_chi over [10,100] = %.6e\n', max(E_chi(mask10)));
    fprintf('max E_s   over [10,100] = %.6e\n', max(E_s(mask10)));
    fprintf('E_chi(end) = %.6e, E_s(end) = %.6e\n', E_chi(end), E_s(end));
end

function print_at(t, E_chi, E_s, target, label)
    [~, idx] = min(abs(t - target));
    fprintf('%-10s -> nearest sample t=%.4f: E_chi=%.6f, E_s=%.6f\n', ...
        label, t(idx), E_chi(idx), E_s(idx));
end

function report_crossing(name, t, E, thresh)
    below = E <= thresh;
    first_idx = find(below, 1, 'first');
    % sustained index: last index of the longest suffix that is entirely below thresh
    sustained_idx = find(~below, 1, 'last');
    if isempty(sustained_idx)
        sustained_idx = 1; % below threshold for the entire trajectory
    else
        sustained_idx = sustained_idx + 1;
        if sustained_idx > numel(t)
            sustained_idx = NaN; % never sustained (last sample still above)
        end
    end
    if isempty(first_idx)
        fprintf('%s <= %.4g : NEVER entered\n', name, thresh);
        return;
    end
    if isnan(sustained_idx)
        fprintf('%s <= %.4g : first entry t=%.4f, but NOT sustained (re-exceeds threshold later, last sample still above)\n', ...
            name, thresh, t(first_idx));
    else
        fprintf('%s <= %.4g : first entry t=%.4f, sustained from t=%.4f onward\n', ...
            name, thresh, t(first_idx), t(sustained_idx));
    end
end
