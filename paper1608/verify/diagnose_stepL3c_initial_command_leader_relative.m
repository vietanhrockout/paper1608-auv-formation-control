function diagnose_stepL3c_initial_command_leader_relative()
% DIAGNOSE_STEPL3C_INITIAL_COMMAND_LEADER_RELATIVE
%
% Step L.3c
%
% Compare initial Eq. (31) command under:
%
%   A) current virtual-reference formation errors
%   B) leader-relative follower formation errors
%
% Purpose:
%   Determine whether the formation-error architecture mismatch found
%   in L.3a can explain the O(1e6)-O(1e7) initial force commands.
%
% IMPORTANT:
%   NO ODE simulation.
%   NO production controller modification.
%   NO formation_error.m modification.
%   NO parameter tuning.
%   NO solver modification.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    cfg     = nn_config();
    sat_cfg = saturation_config();

    [eta_init, nu_init] = initial_conditions();
    offsets = formation_offsets();

    t0 = 0;

    omega0 = zeros(6,1);
    Wa0    = zeros(cfg.actor_n_nodes,6);
    Wc0    = zeros(cfg.critic_n_nodes,1);

    %% ============================================================
    % Earth-frame initial velocities
    % =============================================================

    eta_dot = zeros(6,3);

    for i = 1:3
        J = jacobian_J(eta_init(:,i));
        eta_dot(:,i) = J * nu_init(:,i);
    end

    [eta_d, eta_d_dot, ~] = reference_1608(t0);

    %% ============================================================
    % Architecture A: current implementation
    % =============================================================

    chi_A = zeros(6,3);
    vel_A = zeros(6,3);

    for i = 1:3
        [chi_A(:,i), vel_A(:,i)] = ...
            formation_error( ...
                eta_init(:,i), ...
                eta_dot(:,i), ...
                t0, i);
    end

    %% ============================================================
    % Architecture B: actual-leader-relative followers
    % =============================================================

    chi_B = zeros(6,3);
    vel_B = zeros(6,3);

    % Leader remains reference tracking
    chi_B(:,1) = eta_init(:,1) - eta_d;
    vel_B(:,1) = eta_dot(:,1) - eta_d_dot;

    % Followers use actual leader
    for i = 2:3
        chi_B(:,i) = ...
            eta_init(:,i) ...
            - eta_init(:,1) ...
            - offsets(:,i);

        vel_B(:,i) = ...
            eta_dot(:,i) ...
            - eta_dot(:,1);
    end

    %% ============================================================
    % Exact architecture oracles from L.3a
    % =============================================================

    assert(norm(chi_A(:,1)-chi_B(:,1),inf) < 1e-12);
    assert(norm(vel_A(:,1)-vel_B(:,1),inf) < 1e-12);

    assert(norm(vel_B(:,2),inf) < 1e-12);
    assert(norm(vel_B(:,3),inf) < 1e-12);

    expected_chi_B_xyz = [ ...
          6,  -8, -12;
          6,  -9,  -5;
         16,  -4,  -8];

    assert(norm( ...
        chi_B(1:3,:) - expected_chi_B_xyz, inf) < 1e-12);

    %% ============================================================
    % Output
    % =============================================================

    out_file = fullfile( ...
        fileparts(project_root), ...
        'l3c_results.txt');

    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP L.3c -- INITIAL COMMAND UNDER LEADER-RELATIVE ERRORS\n');
    p('============================================================\n');

    p('\nARCHITECTURE INPUTS\n');

    for i = 1:3
        p('\nAUV%d\n', i-1);

        p('chi_A xyz = [% .6f % .6f % .6f]\n', ...
            chi_A(1,i), chi_A(2,i), chi_A(3,i));

        p('chi_B xyz = [% .6f % .6f % .6f]\n', ...
            chi_B(1,i), chi_B(2,i), chi_B(3,i));

        p('vel_A xyz = [% .6f % .6f % .6f]\n', ...
            vel_A(1,i), vel_A(2,i), vel_A(3,i));

        p('vel_B xyz = [% .6f % .6f % .6f]\n', ...
            vel_B(1,i), vel_B(2,i), vel_B(3,i));
    end

    %% ============================================================
    % Important zero-velocity regularization diagnostic
    % =============================================================

    p('\n============================================================\n');
    p(' NEGATIVE SIGNED-POWER ZERO BEHAVIOR\n');
    p('============================================================\n');

    alpha1 = simulation_params().alpha1;

    g_zero = sigpow_negative( ...
        0, 1-alpha1, 'regularized', 1e-6);

    g_eps = sigpow_negative( ...
        1e-12, 1-alpha1, 'regularized', 1e-6);

    p('sigpow_negative(0, -0.2)     = %.12e\n', g_zero);
    p('sigpow_negative(1e-12,-0.2)  = %.12e\n', g_eps);

    assert(g_zero == 0, ...
        'L.3c oracle failed: current regularization should return zero at x=0.');

    %% ============================================================
    % Sigma branches
    % =============================================================

    modes = { ...
        'paper_literal', ...
        'sign_flip_candidate', ...
        'eq29_consistent'};

    tauB_followers = zeros(6,2,numel(modes));

    for m = 1:numel(modes)

        params = simulation_params();

        params.sigma_mode = modes{m};
        params = derived_params(params);

        p('\n');
        p('============================================================\n');
        p('SIGMA MODE: %s\n', modes{m});
        p('============================================================\n');

        for i = 1:3

            eta = eta_init(:,i);

            %% ----------------------------------------------------
            % Architecture A
            % -----------------------------------------------------

            resultA = evaluate_eq31_from_errors( ...
                eta, ...
                chi_A(:,i), ...
                vel_A(:,i), ...
                t0, ...
                omega0, ...
                Wa0, ...
                Wc0, ...
                params, ...
                cfg, ...
                sat_cfg);

            %% Production controller oracle for A
            [tau_prod, ~] = controller_rl( ...
                eta, eta_dot(:,i), t0, i, ...
                omega0, Wa0, params, cfg);

            prod_err = norm( ...
                resultA.tau_cmd - tau_prod, inf);

            prod_scale = max(1, norm(tau_prod,inf));

            assert(prod_err < 1e-10*prod_scale, ...
                ['L.3c FAIL: diagnostic Eq.31 algebra does not ' ...
                 'reconstruct production controller.']);

            %% ----------------------------------------------------
            % Architecture B
            % -----------------------------------------------------

            resultB = evaluate_eq31_from_errors( ...
                eta, ...
                chi_B(:,i), ...
                vel_B(:,i), ...
                t0, ...
                omega0, ...
                Wa0, ...
                Wc0, ...
                params, ...
                cfg, ...
                sat_cfg);

            %% ----------------------------------------------------
            % AUV0 must be exactly identical
            % -----------------------------------------------------

            if i == 1

                assert(norm( ...
                    resultA.tau_cmd-resultB.tau_cmd,inf) ...
                    < 1e-10*max(1,norm(resultA.tau_cmd,inf)));

                assert(abs(resultA.r_cmd-resultB.r_cmd) ...
                    < 1e-10*max(1,abs(resultA.r_cmd)));

                assert(norm( ...
                    resultA.vc_raw-resultB.vc_raw) ...
                    < 1e-10*max(1,norm(resultA.vc_raw)));
            end

            %% ----------------------------------------------------
            % Followers: exact zero-velocity behavior
            % -----------------------------------------------------

            if i >= 2

                assert(norm(vel_B(:,i),inf) < 1e-12);

                assert(norm( ...
                    resultB.sig_v_neg,inf) < 1e-12);

                assert(norm( ...
                    resultB.term_surface,inf) < 1e-12);

                assert(norm( ...
                    resultB.term_q,inf) < 1e-12);

                assert(norm( ...
                    resultB.term_k1,inf) < 1e-12);

                assert(norm( ...
                    resultB.term_aw,inf) < 1e-12);

                tau_expected = ...
                    [5.919; 6.270; 6.270; 0; 0; 0];

                assert(norm( ...
                    resultB.tau_cmd-tau_expected,inf) < 1e-3, ...
                    'Unexpected exact-zero follower command.');

                tauB_followers(:,i-1,m) = ...
                    resultB.tau_cmd;
            end

            %% ----------------------------------------------------
            % Print comparison
            % -----------------------------------------------------

            p('\n------------------------------------------------------------\n');
            p('AUV%d\n', i-1);
            p('------------------------------------------------------------\n');

            p('||s_A||_inf = %.12e\n', ...
                norm(resultA.s,inf));

            p('||s_B||_inf = %.12e\n', ...
                norm(resultB.s,inf));

            p('||vel_A||_inf = %.12e\n', ...
                norm(vel_A(:,i),inf));

            p('||vel_B||_inf = %.12e\n', ...
                norm(vel_B(:,i),inf));

            p('||sig_v_neg A||_inf = %.12e\n', ...
                norm(resultA.sig_v_neg,inf));

            p('||sig_v_neg B||_inf = %.12e\n', ...
                norm(resultB.sig_v_neg,inf));

            p('\nARCHITECTURE A\n');

            p('max |tau_surface| force = %.12e N\n', ...
                max(abs(resultA.tau_surface(1:3))));

            p('max |tau_q| force       = %.12e N\n', ...
                max(abs(resultA.tau_q(1:3))));

            p('max |tau_k1| force      = %.12e N\n', ...
                max(abs(resultA.tau_k1(1:3))));

            p('max |tau_robust| force  = %.12e N\n', ...
                max(abs(resultA.tau_robust(1:3))));

            p('max |tau_cmd| force     = %.12e N\n', ...
                max(abs(resultA.tau_cmd(1:3))));

            p('r_cmd                   = %.12e\n', ...
                resultA.r_cmd);

            p('||v_c raw||             = %.12e\n', ...
                norm(resultA.vc_raw));

            p('\nARCHITECTURE B\n');

            p('max |tau_surface| force = %.12e N\n', ...
                max(abs(resultB.tau_surface(1:3))));

            p('max |tau_q| force       = %.12e N\n', ...
                max(abs(resultB.tau_q(1:3))));

            p('max |tau_k1| force      = %.12e N\n', ...
                max(abs(resultB.tau_k1(1:3))));

            p('max |tau_robust| force  = %.12e N\n', ...
                max(abs(resultB.tau_robust(1:3))));

            p('tau_cmd xyz = [% .12e % .12e % .12e]\n', ...
                resultB.tau_cmd(1), ...
                resultB.tau_cmd(2), ...
                resultB.tau_cmd(3));

            p('max |tau_cmd| force     = %.12e N\n', ...
                max(abs(resultB.tau_cmd(1:3))));

            p('max |tau_act| force     = %.12e N\n', ...
                max(abs(resultB.tau_act(1:3))));

            p('r_cmd                   = %.12e\n', ...
                resultB.r_cmd);

            p('||Phi||                 = %.12e\n', ...
                norm(resultB.Phi));

            p('||v_c raw||             = %.12e\n', ...
                norm(resultB.vc_raw));

            p('\nA/B RATIOS\n');

            p('tau force ratio A/B = %.12e\n', ...
                max(abs(resultA.tau_cmd(1:3))) / ...
                max(max(abs(resultB.tau_cmd(1:3))),eps));

            p('cost ratio A/B      = %.12e\n', ...
                resultA.r_cmd / max(resultB.r_cmd,eps));
        end
    end

    %% ============================================================
    % Sigma invariance of exact-zero follower command
    % =============================================================

    p('\n============================================================\n');
    p(' EXACT-ZERO FOLLOWER SIGMA INVARIANCE\n');
    p('============================================================\n');

    for i = 1:2

        tau_ref = tauB_followers(:,i,1);

        for m = 2:numel(modes)

            err = norm( ...
                tauB_followers(:,i,m)-tau_ref,inf);

            p('Follower %d mode %d difference = %.12e\n', ...
                i, m, err);

            assert(err < 1e-12);
        end
    end

    %% ============================================================
    % Exact cost oracle
    % =============================================================

    expected_r1 = 161.0113660361;
    expected_r2 = 233.0113660361;

    params = simulation_params();

    B1 = evaluate_eq31_from_errors( ...
        eta_init(:,2), chi_B(:,2), vel_B(:,2), ...
        t0, omega0, Wa0, Wc0, params, cfg, sat_cfg);

    B2 = evaluate_eq31_from_errors( ...
        eta_init(:,3), chi_B(:,3), vel_B(:,3), ...
        t0, omega0, Wa0, Wc0, params, cfg, sat_cfg);

    assert(abs(B1.r_cmd-expected_r1) < 1e-9);
    assert(abs(B2.r_cmd-expected_r2) < 1e-9);

    p('\nExpected exact leader-relative follower costs:\n');
    p('AUV1 r_cmd = %.12f\n', B1.r_cmd);
    p('AUV2 r_cmd = %.12f\n', B2.r_cmd);

    p('\n============================================================\n');
    p(' STEP L.3c COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end


% ========================================================================
% Local diagnostic implementation of Eq. (31)
% ========================================================================

function out = evaluate_eq31_from_errors( ...
    eta, chi, vel_err, t, ...
    omega_aw, Wa, Wc, params, cfg, sat_cfg)

    alpha1 = params.alpha1;

    L      = gain_matrix_L(chi, params);
    Ltilde = gain_matrix_Ltilde(chi, params);

    s = sliding_surface(chi, vel_err, params);

    sig_v_2minus = ...
        sigpow(vel_err, 2-alpha1);

    term_surface = ...
        -(1/alpha1) * ...
        (Ltilde+L) * sig_v_2minus;

    term_robust = ...
        -params.k0 * sign(s);

    sig_v_neg = sigpow_negative( ...
        vel_err, ...
        1-alpha1, ...
        'regularized', ...
        1e-6);

    gv = (1/alpha1) * sig_v_neg;

    q = pt_reaching_term(s, params);

    term_q = ...
        -gv .* q;

    term_k1 = ...
        -gv .* (params.k1*s);

    term_aw = ...
        -gv .* omega_aw;

    [~,~,eta_ddot_ref] = reference_1608(t);

    term_reference = ...
        params.ref_accel_sign * eta_ddot_ref;

    f_rl = actor_output( ...
        chi, vel_err, Wa, cfg);

    term_rl = -f_rl;

    virtual_accel = ...
          term_surface ...
        + term_robust ...
        + term_q ...
        + term_k1 ...
        + term_aw ...
        + term_reference ...
        + term_rl;

    J = jacobian_J(eta);
    M = mass_matrix();

    tau_cmd = ...
        (J') * ((J') \ ...
        (M * (J \ virtual_accel)));

    [tau_act, delta_tau] = sat_vector( ...
        tau_cmd, ...
        sat_cfg.tau_min, ...
        sat_cfg.tau_max);

    r_cmd = strategic_utility( ...
        chi, tau_cmd);

    [ce, Phi] = bellman_error( ...
        chi, vel_err, Wc, ...
        tau_cmd, params, cfg);

    vc_raw = ...
        -params.lambda_c * ce * Phi;

    out = struct();

    out.s = s;

    out.sig_v_neg = sig_v_neg;

    out.term_surface   = term_surface;
    out.term_robust    = term_robust;
    out.term_q         = term_q;
    out.term_k1        = term_k1;
    out.term_aw        = term_aw;
    out.term_reference = term_reference;
    out.term_rl        = term_rl;

    out.tau_surface = virtual_to_tau( ...
        eta, term_surface);

    out.tau_robust = virtual_to_tau( ...
        eta, term_robust);

    out.tau_q = virtual_to_tau( ...
        eta, term_q);

    out.tau_k1 = virtual_to_tau( ...
        eta, term_k1);

    out.tau_aw = virtual_to_tau( ...
        eta, term_aw);

    out.tau_cmd   = tau_cmd;
    out.tau_act   = tau_act;
    out.delta_tau = delta_tau;

    out.r_cmd = r_cmd;
    out.ce     = ce;
    out.Phi    = Phi;
    out.vc_raw = vc_raw;
end


function tau = virtual_to_tau(eta, virtual_accel)

    J = jacobian_J(eta);
    M = mass_matrix();

    tau = ...
        (J') * ((J') \ ...
        (M * (J \ virtual_accel)));
end
