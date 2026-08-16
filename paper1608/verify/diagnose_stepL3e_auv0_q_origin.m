function diagnose_stepL3e_auv0_q_origin()
% DIAGNOSE_STEPL3E_AUV0_Q_ORIGIN
%
% Pure algebraic/numerical diagnostic. NO ODE simulation.
%
% Goal: Isolate, term-by-term, why AUV0 (leader) at t=0 with
%   chi_0 = eta_0(0) - eta_d0(0) - eta_l00 = [6,6,16,0,0,0]^T, vel_0 = 0
% produces s_0 ~ O(10^3), q(s_0) ~ O(10^5..10^6), and tau_cmd(0) ~ O(10^7) N.
%
% Determine whether this scale is an unavoidable consequence of Paper 1608
% Table 1 parameters (a1, a2, alpha2, alpha3, zeta1) applied literally to
% Eq. (21)/(22)/(25)/(31), or a parameter-derivation bug.
%
% NO production modifications. NO clipping. NO tuning.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'nn'));

    params = simulation_params();   % active eq29_consistent branch
    cfg = nn_config();

    out_file = fullfile(fileparts(project_root), 'l3e_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP L.3e -- AUV0 LARGE q(s) ORIGIN AUDIT\n');
    p('============================================================\n');

    %% ============================================================
    % 1. Derived Table-1 parameter dump
    % =============================================================

    p('\nDERIVED PARAMETER DUMP (simulation_params -> eq29_consistent)\n');
    p('c                = %.12f\n', params.c);
    p('alpha1           = %.12f\n', params.alpha1);
    p('b1               = %.12f\n', params.b1);
    p('b2               = %.12f\n', params.b2);
    p('eps0             = %.12f\n', params.eps0);
    p('T2star           = %.12f\n', params.T2star);
    p('c*alpha1         = %.12f\n', params.c*params.alpha1);
    p('alpha2 (b1-1/ca1)= %.12f\n', params.alpha2);
    p('alpha3 (b2-1/ca1)= %.12f\n', params.alpha3);
    p('a1               = %.12f\n', params.a1);
    p('a2               = %.12f\n', params.a2);
    p('zeta1            = %.12f\n', params.zeta1);
    p('zeta2            = %.12f\n', params.zeta2);
    p('zeta3            = %.12f\n', params.zeta3);
    p('sigma1 (active)  = %.12f\n', params.sigma1);
    p('sigma2 (active)  = %.12f\n', params.sigma2);
    p('sigma_mode       = %s\n', params.sigma_mode);
    p('k0 (diag)        = %.12f\n', params.k0(1,1));
    p('k1 (diag)        = %.12f\n', params.k1(1,1));

    %% ============================================================
    % 2. AUV0 initial formation error (i_auv = 1 == leader in code)
    % =============================================================

    [eta_init, nu_init] = initial_conditions();
    eta0 = eta_init(:,1);
    J0 = jacobian_J(eta0);
    eta0_dot = J0 * nu_init(:,1);

    [chi0, vel0] = formation_error(eta0, eta0_dot, 0, 1);

    p('\n============================================================\n');
    p(' AUV0 INITIAL CONDITION\n');
    p('============================================================\n');
    p('eta_0(0)          = [%.6f %.6f %.6f %.6f %.6f %.6f]\n', eta0);
    p('eta_dot_0(0)      = [%.6f %.6f %.6f %.6f %.6f %.6f]\n', eta0_dot);
    p('chi_0             = [%.6f %.6f %.6f %.6f %.6f %.6f]\n', chi0);
    p('vel_0             = [%.6f %.6f %.6f %.6f %.6f %.6f]\n', vel0);

    % NOTE: vel_0 is NOT exactly zero for AUV0: even though nu_init=0 (AUV
    % at rest), vel_err = eta_dot - eta_d0_dot(0), and eta_d0_dot(0) =
    % [0.1, -0.1, -0.2, 0,0,0] (Eq. 57 leader reference velocity at t=0).
    % So vel_0 = -eta_d0_dot(0) = [-0.1, 0.1, 0.2, 0,0,0].

    %% ============================================================
    % 3. Term-by-term l_chi_ij for x, y, z DOFs
    % =============================================================

    dof_names = {'x','y','z'};
    a1 = params.a1;
    a2 = params.a2;
    alpha2 = params.alpha2;
    alpha3 = params.alpha3;
    ca1 = params.c * params.alpha1;

    p('\n============================================================\n');
    p(' TERM-BY-TERM l_chi COMPUTATION (Eq. 21)\n');
    p(' l_chi_ij = (a1*|chi|^alpha2 + a2*|chi|^alpha3)^(c*alpha1)\n');
    p('============================================================\n');

    L0 = gain_matrix_L(chi0, params);
    s0 = sliding_surface(chi0, vel0, params);

    for j = 1:3
        cj = abs(chi0(j));
        term1 = a1 * (cj ^ alpha2);
        term2 = a2 * (cj ^ alpha3);
        base = term1 + term2;
        lval = base ^ ca1;

        p('\nDOF %s: |chi| = %.6f\n', dof_names{j}, cj);
        p('  a1*|chi|^alpha2   = %.12e\n', term1);
        p('  a2*|chi|^alpha3   = %.12e\n', term2);
        p('  base (sum)        = %.12e\n', base);
        p('  l_chi = base^(ca1)= %.12e\n', lval);
        p('  gain_matrix_L(j,j)= %.12e  (match: %d)\n', L0(j,j), abs(L0(j,j)-lval)<1e-6);
        p('  s0_j = l_chi*chi_j= %.12e\n', lval*chi0(j));
        p('  sliding_surface(j)= %.12e  (match: %d)\n', s0(j), abs(s0(j)-lval*chi0(j))<1e-3);
    end

    %% ============================================================
    % 4. q(s0) decomposition (Eq. 22-line reaching law)
    % =============================================================

    q0 = pt_reaching_term(s0, params);

    p('\n============================================================\n');
    p(' q(s0) DECOMPOSITION: q(s) = sig^z1( sigma1*sig^z2(s) + sigma2*sig^z3(s) )\n');
    p('============================================================\n');

    z1 = params.zeta1; z2 = params.zeta2; z3 = params.zeta3;

    for j = 1:3
        sj = s0(j);
        sig_z2 = sign(sj)*abs(sj)^z2;
        sig_z3 = sign(sj)*abs(sj)^z3;
        inner = params.sigma1*sig_z2 + params.sigma2*sig_z3;
        qj = sign(inner)*abs(inner)^z1;

        p('\nDOF %s: s0 = %.6e\n', dof_names{j}, sj);
        p('  sig^z2(s0)         = %.12e\n', sig_z2);
        p('  sig^z3(s0)         = %.12e\n', sig_z3);
        p('  inner = sig1*.. +sig2*.. = %.12e\n', inner);
        p('  q0_j = sig^z1(inner) = %.12e\n', qj);
        p('  pt_reaching_term(j)  = %.12e (match: %d)\n', q0(j), abs(q0(j)-qj)<1e-3*max(1,abs(qj)));
    end

    %% ============================================================
    % 5. sigpow_negative(vel0, 1-alpha1) -- AUV0's actual (small, nonzero)
    %    velocity error, NOT the zero-velocity singularity case audited
    %    in Step L.3d. Reported here for completeness of the command
    %    reconstruction chain.
    % =============================================================

    eps_v = 1e-6;
    sig_v_neg = sigpow_negative(vel0, 1-params.alpha1, 'regularized', eps_v);
    sig_v_neg_literal = sigpow_negative(vel0, 1-params.alpha1, 'literal', eps_v);

    p('\n============================================================\n');
    p(' sig^(1-alpha1)(vel_0) FACTOR (AUV0, vel_0 small but nonzero)\n');
    p('============================================================\n');
    p('1-alpha1                     = %.12f\n', 1-params.alpha1);
    for j = 1:3
        p('DOF %s: vel0=%.6f  sig_v_neg(regularized)=%.12e  sig_v_neg(literal)=%.12e\n', ...
            dof_names{j}, vel0(j), sig_v_neg(j), sig_v_neg_literal(j));
    end
    assert(max(abs(sig_v_neg(1:3)-sig_v_neg_literal(1:3))) < 1e-2);

    %% ============================================================
    % 6. Full command reconstruction: tau_reaching, tau_cmd
    % =============================================================

    Ltilde0 = gain_matrix_Ltilde(chi0, params);
    a1_inv = 1/params.alpha1;

    term_surface = -a1_inv * (Ltilde0+L0) * sigpow(vel0, 2-params.alpha1);
    term_robust = -params.k0*sign(s0);

    omega_aw0 = zeros(6,1);
    F0 = q0 + params.k1*s0 + omega_aw0;
    term_reaching = -a1_inv * sig_v_neg .* F0;

    [~, ~, eta_d0_ddot] = reference_1608(0);
    term_reference = params.ref_accel_sign * eta_d0_ddot;

    Wa0 = cfg.initial_Wa(:,:,1);
    f_rl0 = actor_output(chi0, vel0, Wa0, cfg);
    term_rl = -f_rl0;

    virtual_accel = term_surface + term_robust + term_reaching + term_reference + term_rl;

    M = mass_matrix();
    J = jacobian_J(eta0);
    tau_cmd = (J') * ((J') \ (M * (J \ virtual_accel)));

    p('\n============================================================\n');
    p(' FULL COMMAND RECONSTRUCTION AT t=0, AUV0\n');
    p('============================================================\n');
    p('term_surface   = [%.6e %.6e %.6e]\n', term_surface(1:3));
    p('term_robust    = [%.6e %.6e %.6e]\n', term_robust(1:3));
    p('F0 = q0+k1*s0  = [%.6e %.6e %.6e]\n', F0(1:3));
    p('term_reaching  = [%.6e %.6e %.6e]\n', term_reaching(1:3));
    p('term_reference = [%.6e %.6e %.6e]\n', term_reference(1:3));
    p('term_rl        = [%.6e %.6e %.6e]\n', term_rl(1:3));
    p('virtual_accel  = [%.6e %.6e %.6e]\n', virtual_accel(1:3));
    p('tau_cmd        = [%.6e %.6e %.6e]\n', tau_cmd(1:3));
    p('max|tau_cmd|   = %.6e N\n', max(abs(tau_cmd)));

    % Cross-check against actual controller_rl.m production function
    [tau_cmd_prod, terms_prod] = controller_rl(eta0, eta0_dot, 0, 1, omega_aw0, Wa0, params, cfg);
    p('\ntau_cmd (production controller_rl.m) = [%.6e %.6e %.6e %.6e %.6e %.6e]\n', tau_cmd_prod);
    p('max|tau_cmd_prod|                     = %.6e N\n', max(abs(tau_cmd_prod)));
    p('Consistency with manual reconstruction: max abs diff = %.6e\n', max(abs(tau_cmd-tau_cmd_prod)));
    assert(max(abs(tau_cmd-tau_cmd_prod)) < 1e-3 * max(abs(tau_cmd_prod)));

    %% ============================================================
    % 7. Sensitivity: what would s0 be if a1=a2=1 (sanity baseline)?
    % =============================================================

    p('\n============================================================\n');
    p(' SANITY BASELINE: a1=a2=1 (illustrative only, NOT paper value)\n');
    p('============================================================\n');
    for j = 1:3
        cj = abs(chi0(j));
        base_sanity = 1*(cj^alpha2) + 1*(cj^alpha3);
        l_sanity = base_sanity^ca1;
        p('DOF %s: l_chi(a1=a2=1) = %.6f, s0=%.6f  [vs actual a1=%.4f,a2=%.4f -> l=%.6f, s0=%.6f]\n', ...
            dof_names{j}, l_sanity, l_sanity*chi0(j), a1, a2, L0(j,j), s0(j));
    end

    %% ============================================================
    % 8. Downstream coupling: strategic_utility / critic reward magnitude
    % =============================================================

    p('\n============================================================\n');
    p(' DOWNSTREAM COUPLING: strategic_utility(chi0, tau_cmd) [Eq. 16]\n');
    p('============================================================\n');

    r_raw = strategic_utility(chi0, tau_cmd_prod);
    sat_cfg = saturation_config();
    [tau_act0, delta_tau0] = sat_vector(tau_cmd_prod, sat_cfg.tau_min, sat_cfg.tau_max);
    r_sat = strategic_utility(chi0, tau_act0);

    p('tau_cmd (raw, unsaturated)   max|.| = %.6e N\n', max(abs(tau_cmd_prod)));
    p('tau_act (saturated, applied) max|.| = %.6e N\n', max(abs(tau_act0)));
    p('r_i(t) using RAW tau_cmd in Eq.16   = %.6e\n', r_raw);
    p('r_i(t) using SATURATED tau_act      = %.6e\n', r_sat);
    p('ratio r_raw / r_sat                 = %.6e\n', r_raw/max(r_sat,eps));

    p('\n============================================================\n');
    p(' STEP L.3e COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end
