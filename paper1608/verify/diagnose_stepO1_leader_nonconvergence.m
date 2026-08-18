function diagnose_stepO1_leader_nonconvergence()
    % DIAGNOSE_STEPO1_LEADER_NONCONVERGENCE
    % Issue O root-cause probe: term-by-term audit of controller_rl.m (Eq.31)
    % for AUV0 (leader) and AUV1 (follower) at several timestamps from the
    % saved Phase B.2 (15s) trajectory, to determine whether the observed
    % non-convergence is (a) a genuine saturation-starvation consequence of
    % tau_max=150N being too small relative to what Eq.31's terms demand, or
    % (b) a sign/logic inconsistency causing the saturated command to push in
    % the WRONG direction (i.e. away from chi=0 rather than toward it).
    %
    % Method: load phase_b2_result.mat (no re-simulation), unpack eta/nu for
    % AUV0 and AUV1 at t = [0, 1, 5, 10, 15], recompute chi, vel_err, s, and
    % every term of controller_rl.m's decomposition, then:
    %   1. Check sign(virtual_accel) vs the "correction sign" -sign(chi) per DOF.
    %   2. Check sign(tau_cmd) and sign(tau_act) (post-saturation) similarly.
    %   3. Directly compute the PHYSICAL acceleration eta_ddot that tau_act
    %      actually produces via the true dynamics (M, C, D, J), independent
    %      of the (possibly saturation-corrupted) virtual_accel design value,
    %      to see whether the delivered force is even large enough, in the
    %      right direction, to matter for the surge/sway/heave channels.

    paths = project_paths();

    data = load(fullfile(paths.validation, 'phase_b2_result.mat'));
    res = data.res;
    params = res.params;
    cfg = nn_config();
    sat_cfg = saturation_config();

    sample_t = [0, 1, 5, 10, 15];
    auv_list = [1, 2]; % AUV0 (leader, i=1) and AUV1 (follower, i=2) in 1-indexed convention
    auv_names = {'AUV0(leader)', 'AUV1(follower)'};

    fprintf('=== ISSUE O DIAGNOSTIC: term-by-term audit ===\n\n');

    for auv_idx = 1:numel(auv_list)
        i_auv = auv_list(auv_idx);
        fprintf('########## %s (i_auv=%d) ##########\n', auv_names{auv_idx}, i_auv);

        for st = sample_t
            [~, k] = min(abs(res.t - st));
            t = res.t(k);
            Xk = res.X(k, :).';
            [eta_m, nu_m, omega_m, Wa_l, ~] = unpack_states(Xk, cfg);

            eta = eta_m(:, i_auv);
            nu  = nu_m(:, i_auv);
            J = jacobian_J(eta);
            eta_dot = J * nu;

            [chi, vel_err] = formation_error(eta, eta_dot, t, i_auv);
            s = sliding_surface(chi, vel_err, params);

            [tau_cmd, terms] = controller_rl(eta, eta_dot, t, i_auv, omega_m(:, i_auv), Wa_l{i_auv}, params, cfg);
            [tau_act, delta_tau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);

            % Physical acceleration actually delivered by tau_act (true dynamics)
            M = mass_matrix();
            C = coriolis_matrix(nu);
            D = damping_matrix(nu);
            g_rest = restoring_force(eta);
            nu_dot_physical = M \ (J' * tau_act - C * nu - D * nu - g_rest);

            fprintf('--- t=%.4f ---\n', t);
            fprintf('  chi          = [%s]\n', num2str(chi', '%10.4f'));
            fprintf('  vel_err      = [%s]\n', num2str(vel_err', '%10.4e'));
            fprintf('  s            = [%s]\n', num2str(s', '%10.4f'));
            fprintf('  term_surface = [%s]\n', num2str(terms.term_surface', '%10.4e'));
            fprintf('  term_robust  = [%s]\n', num2str(terms.term_robust', '%10.4e'));
            fprintf('  term_reaching= [%s]\n', num2str(terms.term_reaching', '%10.4e'));
            fprintf('  term_reference=[%s]\n', num2str(terms.term_reference', '%10.4e'));
            fprintf('  term_rl      = [%s]\n', num2str(terms.term_rl', '%10.4e'));
            fprintf('  virtual_accel= [%s]\n', num2str(terms.virtual_accel', '%10.4e'));
            fprintf('  tau_cmd      = [%s]\n', num2str(tau_cmd', '%10.4e'));
            fprintf('  tau_act      = [%s]\n', num2str(tau_act', '%10.4f'));
            fprintf('  delta_tau    = [%s]\n', num2str(delta_tau', '%10.4e'));
            fprintf('  nu_dot_phys  = [%s]  (actual accel delivered by tau_act via M,C,D,J)\n', num2str(nu_dot_physical', '%10.4e'));

            % Sign consistency check: for correction, we want the physically
            % delivered acceleration (position DOFs 1-3) to push eta AWAY
            % from chi's current sign, i.e. sign(nu_dot_physical(1:3)) should
            % tend to be opposite sign(chi(1:3)) (eventually), OR at minimum
            % tau_act's commanded direction (post-saturation, pre-dynamics)
            % should be -sign(chi) if the controller is behaving as a
            % robust/reaching-law controller near s~sign(chi)-dominated.
            sign_check = -sign(chi(1:3)) .* sign(tau_act(1:3));
            fprintf('  sign(-chi)*sign(tau_act) [1:3] = [%s]  (+1 = correcting direction, -1 = WRONG/diverging direction)\n', ...
                num2str(sign_check', '%10.1f'));
            fprintf('\n');
        end
        fprintf('\n');
    end

    fprintf('=== END DIAGNOSTIC ===\n');
end
