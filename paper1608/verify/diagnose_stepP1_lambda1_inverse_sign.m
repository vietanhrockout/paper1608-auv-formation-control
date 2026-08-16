function diagnose_stepP1_lambda1_inverse_sign()
    % DIAGNOSE_STEPP1_LAMBDA1_INVERSE_SIGN
    % Issue P probe (raised by independent audit of this session's Issue O
    % work): verifies, by pure scalar algebra (no simulation state needed),
    % whether Eq.(31)'s literal reaching-law term
    %     -sig^{1-alpha1}(v)/alpha1 * F        (F = q(s)+k1*s+omega)
    % correctly cancels against Eq.(23)'s Lambda1 = diag{|v|^{alpha1-1}}
    % (UNSIGNED, confirmed against the raw PDF text at pdf_extracted_text.txt
    % lines 558-584) when substituted into ds/dt = (L+Ltilde)*v + alpha1*Lambda1*vdot.
    %
    % Algebraic claim under test:
    %   alpha1 * Lambda1 * [ -sig^{1-alpha1}(v)/alpha1 * F ]
    %     = -Lambda1 .* sig^{1-alpha1}(v) .* F
    %     = -( |v|^{alpha1-1} ) .* ( sign(v).*|v|^{1-alpha1} ) .* F
    %     = -sign(v) .* F                                   <-- PAPER-LITERAL (current code)
    %
    %   vs. the proof-consistent unsigned inverse of Lambda1:
    %   alpha1 * Lambda1 * [ -|v|^{1-alpha1}/alpha1 * F ]
    %     = -( |v|^{alpha1-1} ) .* ( |v|^{1-alpha1} ) .* F
    %     = -F                                               <-- PROOF-CONSISTENT
    %
    % If confirmed, this means the paper-literal reaching term's contribution
    % to ds/dt flips sign with sign(v) (chattering/direction-dependent on the
    % ARBITRARY sign of a near-zero velocity error), instead of robustly
    % always being -F (which is what a reaching law needs to drive s -> 0
    % monotonically). This is a candidate root cause for Issue O: once v
    % chatters near 0, the F-term (which dominates virtual_accel by 5-6
    % orders of magnitude per Step O.1's trace) effectively randomizes/flips
    % direction instead of consistently driving s (and hence chi) to zero.

    alpha1 = 1.2;
    F = 5.0; % arbitrary representative positive F = q(s)+k1*s+omega (s>0 case)

    v_grid = [-0.2, -0.1, -1e-3, -1e-6, 1e-6, 1e-3, 0.1, 0.2];

    fprintf('=== ISSUE P.1 DIAGNOSTIC: signed vs unsigned Lambda1^{-1} cancellation ===\n');
    fprintf('alpha1=%.4f, F=%.4f (fixed, representing s>0 case)\n\n', alpha1, F);
    fprintf('%12s %18s %18s %18s %18s\n', 'v', 'sig^{1-a1}(v)', 'paper: -sgn(v)*F', 'unsigned: -F', 'match?');

    all_match_paper_to_negF = true;
    for v = v_grid
        Lambda1 = abs(v)^(alpha1 - 1);
        sig_1ma1 = sign(v) * abs(v)^(1 - alpha1); % production sigpow_negative literal form (no regularization, matches math at v~=0)

        % Reconstruct ds/dt contribution from the F-term under each candidate law
        vdot_paper    = -sig_1ma1 / alpha1 * F;
        ds_paper      = alpha1 * Lambda1 * vdot_paper;      % should equal -sign(v)*F per derivation

        vdot_unsigned = -abs(v)^(1 - alpha1) / alpha1 * F;
        ds_unsigned   = alpha1 * Lambda1 * vdot_unsigned;   % should equal -F per derivation

        expected_paper    = -sign(v) * F;
        expected_unsigned = -F;

        err_paper    = abs(ds_paper - expected_paper);
        err_unsigned = abs(ds_unsigned - expected_unsigned);

        matches_negF = abs(ds_paper - (-F)) < 1e-9;
        if ~matches_negF
            all_match_paper_to_negF = false;
        end

        fprintf('%12.6f %18.6e %18.6e %18.6e %18s\n', v, sig_1ma1, ds_paper, ds_unsigned, mat2str(matches_negF));

        assert(err_paper < 1e-9, 'Paper-literal derivation mismatch at v=%.6f: got %.6e, expected -sgn(v)*F=%.6e', v, ds_paper, expected_paper);
        assert(err_unsigned < 1e-9, 'Unsigned derivation mismatch at v=%.6f: got %.6e, expected -F=%.6e', v, ds_unsigned, expected_unsigned);
    end

    fprintf('\nPASS: paper-literal reaching term algebraically reduces to -sign(v)*F (NOT -F) in every case.\n');
    fprintf('PASS: proof-consistent unsigned |v|^%.1f inverse algebraically reduces to -F in every case (direction-independent of sign(v)).\n', 1-alpha1);
    if all_match_paper_to_negF
        fprintf('UNEXPECTED: paper-literal form matched -F for ALL v -- hypothesis P would be REFUTED.\n');
    else
        fprintf('CONFIRMED: paper-literal form does NOT match -F whenever v<0 -- Issue P hypothesis (sign inconsistency) SURVIVES this algebraic test.\n');
    end
    fprintf('=== END P.1 ===\n');
end
