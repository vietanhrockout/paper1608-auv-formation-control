function diagnose_stepL3d_near_zero_velocity_singularity()
% DIAGNOSE_STEPL3D_NEAR_ZERO_VELOCITY_SINGULARITY
%
% Pure algebraic/numerical diagnostic.
%
% Tests Eq. (31) near vel_err = 0 while chi ~= 0.
%
% Compare:
%   1) literal sig^(1-alpha1)(v)
%   2) current regularized implementation
%
% NO ODE simulation.
% NO production modifications.
% NO parameter tuning.
% NO epsilon tuning.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'math'));

    params = simulation_params();   % active eq29_consistent branch

    alpha1 = params.alpha1;
    zeta1  = params.zeta1;
    zeta2  = params.zeta2;

    eps_v = 1e-6;

    out_file = fullfile(fileparts(project_root), 'l3d_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    %% ============================================================
    % 1. Paper Remark-1 exponent audit
    % =============================================================

    lhs = alpha1*zeta1*zeta2;
    rhs = alpha1 - 1;

    exponent_on_manifold = ...
        1 - alpha1 + alpha1*zeta1*zeta2;

    exponent_generic = ...
        1 - alpha1;

    p('\n');
    p('============================================================\n');
    p(' STEP L.3d -- NEAR-ZERO VELOCITY SINGULARITY AUDIT\n');
    p('============================================================\n');

    p('\nREMARK-1 EXPONENT CHECK\n');
    p('alpha1                     = %.12f\n', alpha1);
    p('zeta1                      = %.12f\n', zeta1);
    p('zeta2                      = %.12f\n', zeta2);

    p('alpha1*zeta1*zeta2         = %.12f\n', lhs);
    p('alpha1 - 1                 = %.12f\n', rhs);

    p('Remark-1 inequality margin = %.12f\n', lhs-rhs);

    p('\nIf s = O(|v|^alpha1):\n');
    p('combined exponent          = %.12f\n', ...
        exponent_on_manifold);

    p('\nIf chi is fixed nonzero and s -> s0 ~= 0:\n');
    p('generic exponent           = %.12f\n', ...
        exponent_generic);

    assert(lhs >= rhs);
    assert(exponent_on_manifold > 0);
    assert(exponent_generic < 0);

    %% ============================================================
    % 2. Build Candidate-B leader-relative follower errors
    % =============================================================

    [eta_init, nu_init] = initial_conditions();
    offsets = formation_offsets();

    eta_dot = zeros(6,3);

    for i = 1:3
        J = jacobian_J(eta_init(:,i));
        eta_dot(:,i) = J*nu_init(:,i);
    end

    chi_B = zeros(6,3);
    vel_B = zeros(6,3);

    [eta_d, eta_d_dot, ~] = reference_1608(0);

    % Leader
    chi_B(:,1) = eta_init(:,1) - eta_d;
    vel_B(:,1) = eta_dot(:,1) - eta_d_dot;

    % Followers
    for i = 2:3

        chi_B(:,i) = ...
            eta_init(:,i) ...
            - eta_init(:,1) ...
            - offsets(:,i);

        vel_B(:,i) = ...
            eta_dot(:,i) ...
            - eta_dot(:,1);
    end

    assert(norm(vel_B(:,2),inf) < 1e-12);
    assert(norm(vel_B(:,3),inf) < 1e-12);

    %% ============================================================
    % 3. Exact zero / one-sided regularization behavior
    % =============================================================

    g0 = sigpow_negative( ...
        0, 1-alpha1, ...
        'regularized', eps_v);

    gp = sigpow_negative( ...
        1e-12, 1-alpha1, ...
        'regularized', eps_v);

    gm = sigpow_negative( ...
        -1e-12, 1-alpha1, ...
        'regularized', eps_v);

    plateau = eps_v^(1-alpha1);

    p('\n============================================================\n');
    p(' REGULARIZATION ZERO BEHAVIOR\n');
    p('============================================================\n');

    p('g_reg(0)         = %.12e\n', g0);
    p('g_reg(+1e-12)    = %.12e\n', gp);
    p('g_reg(-1e-12)    = %.12e\n', gm);
    p('eps_v^(-0.2)     = %.12e\n', plateau);

    assert(g0 == 0);

    assert(abs(gp-plateau) / plateau < 1e-5);
    assert(abs(gm+plateau) / plateau < 1e-5);

    %% ============================================================
    % 4. Static asymptotic coefficients for each follower DOF
    % =============================================================

    p('\n============================================================\n');
    p(' GENERIC OFF-MANIFOLD LIMIT: chi ~= 0, v -> 0\n');
    p('============================================================\n');

    follower_ids = [2 3];
    dof_names = {'x','y','z'};

    M = mass_matrix();

    for ii = 1:numel(follower_ids)

        i = follower_ids(ii);
        chi = chi_B(:,i);

        vel0 = zeros(6,1);

        s0 = sliding_surface(chi, vel0, params);

        q0 = pt_reaching_term(s0, params);

        F0 = q0 + params.k1*s0;

        p('\n------------------------------------------------------------\n');
        p('AUV%d\n', i-1);
        p('------------------------------------------------------------\n');

        for j = 1:3

            Cj = M(j,j) / alpha1 * abs(F0(j));

            plateau_tau = Cj * eps_v^(1-alpha1);

            literal_tau_1e12 = Cj * (1e-12)^(1-alpha1);

            p('\nDOF %s\n', dof_names{j});

            p('chi_j                  = % .12e\n', chi(j));
            p('s0_j                   = % .12e\n', s0(j));
            p('q(s0)_j                = % .12e\n', q0(j));
            p('k1*s0_j                = % .12e\n', params.k1(j,j)*s0(j));

            p('F0_j                    = % .12e\n', F0(j));

            p('C_j                     = %.12e\n', Cj);

            p('regularized plateau     = %.12e N\n', plateau_tau);

            p('literal |tau| @ 1e-12   = %.12e N\n', literal_tau_1e12);

            assert(abs(s0(j)) > 1);
            assert(abs(F0(j)) > 1);
            assert(Cj > 0);
        end
    end

    %% ============================================================
    % 5. Numerical sweep
    %
    % Use the worst representative coordinate:
    % AUV2 x, chi_x = -12
    % =============================================================

    i_test = 3;   % AUV2
    j_test = 1;   % x

    chi = chi_B(:,i_test);

    deltas = [ ...
        1e-12 ...
        1e-10 ...
        1e-8 ...
        1e-6 ...
        1e-4 ...
        1e-2 ...
        1e-1];

    p('\n============================================================\n');
    p(' DETAILED SWEEP: AUV2-x\n');
    p('============================================================\n');

    p(['\n delta         g_reg        tauReach_reg[N]   ' ...
       'g_literal     tauReach_literal[N]\n']);

    tau_reg_pos = zeros(size(deltas));
    tau_lit_pos = zeros(size(deltas));

    for k = 1:numel(deltas)

        d = deltas(k);

        out_reg = evaluate_component( ...
            eta_init(:,i_test), ...
            chi, j_test, +d, ...
            params, 'regularized', eps_v);

        out_lit = evaluate_component( ...
            eta_init(:,i_test), ...
            chi, j_test, +d, ...
            params, 'literal', eps_v);

        tau_reg_pos(k) = abs(out_reg.tau_reaching(j_test));
        tau_lit_pos(k) = abs(out_lit.tau_reaching(j_test));

        p('% .1e   % .6e   % .6e   % .6e   % .6e\n', ...
            d, ...
            out_reg.sig_v_neg(j_test), ...
            out_reg.tau_reaching(j_test), ...
            out_lit.sig_v_neg(j_test), ...
            out_lit.tau_reaching(j_test));
    end

    %% ============================================================
    % 6. Sign jump check
    % =============================================================

    dsmall = 1e-12;

    out_p = evaluate_component( ...
        eta_init(:,i_test), ...
        chi, j_test, +dsmall, ...
        params, 'regularized', eps_v);

    out_0 = evaluate_component( ...
        eta_init(:,i_test), ...
        chi, j_test, 0, ...
        params, 'regularized', eps_v);

    out_m = evaluate_component( ...
        eta_init(:,i_test), ...
        chi, j_test, -dsmall, ...
        params, 'regularized', eps_v);

    p('\n============================================================\n');
    p(' ZERO-CROSSING COMMAND JUMP: AUV2-x\n');
    p('============================================================\n');

    p('tau_cmd(-1e-12) x = % .12e N\n', out_m.tau_cmd(j_test));
    p('tau_cmd(0)      x = % .12e N\n', out_0.tau_cmd(j_test));
    p('tau_cmd(+1e-12) x = % .12e N\n', out_p.tau_cmd(j_test));

    jump_ratio = ...
        max(abs([out_m.tau_cmd(j_test), out_p.tau_cmd(j_test)])) ...
        / max(abs(out_0.tau_cmd(j_test)),1);

    p('jump ratio relative to exact zero = %.12e\n', jump_ratio);

    assert(jump_ratio > 1e6);

    %% ============================================================
    % 7. Log-log scaling slopes
    % =============================================================

    d_literal = logspace(-12,-8,9);

    tau_literal = zeros(size(d_literal));
    tau_reg_inner = zeros(size(d_literal));

    for k = 1:numel(d_literal)

        out1 = evaluate_component( ...
            eta_init(:,i_test), ...
            chi, j_test, d_literal(k), ...
            params, 'literal', eps_v);

        out2 = evaluate_component( ...
            eta_init(:,i_test), ...
            chi, j_test, d_literal(k), ...
            params, 'regularized', eps_v);

        tau_literal(k) = abs(out1.tau_reaching(j_test));
        tau_reg_inner(k) = abs(out2.tau_reaching(j_test));
    end

    pp_lit = polyfit(log10(d_literal), log10(tau_literal), 1);
    pp_reg_inner = polyfit(log10(d_literal), log10(tau_reg_inner), 1);

    d_outer = logspace(-4,-2,9);

    tau_reg_outer = zeros(size(d_outer));

    for k = 1:numel(d_outer)

        out = evaluate_component( ...
            eta_init(:,i_test), ...
            chi, j_test, d_outer(k), ...
            params, 'regularized', eps_v);

        tau_reg_outer(k) = abs(out.tau_reaching(j_test));
    end

    pp_reg_outer = polyfit(log10(d_outer), log10(tau_reg_outer), 1);

    p('\n============================================================\n');
    p(' LOG-LOG SCALING\n');
    p('============================================================\n');

    p('literal near-zero slope      = %.12f\n', pp_lit(1));
    p('regularized inner slope      = %.12f\n', pp_reg_inner(1));
    p('regularized outer slope      = %.12f\n', pp_reg_outer(1));

    assert(abs(pp_lit(1) + 0.2) < 5e-3);
    assert(abs(pp_reg_inner(1)) < 1e-2);
    assert(abs(pp_reg_outer(1) + 0.2) < 2e-2);

    p('\n============================================================\n');
    p(' STEP L.3d COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end

function out = evaluate_component( ...
    eta, chi, j, delta, ...
    params, neg_mode, eps_v)

    alpha1 = params.alpha1;

    vel = zeros(6,1);
    vel(j) = delta;

    L = gain_matrix_L(chi, params);
    Lt = gain_matrix_Ltilde(chi, params);

    s = sliding_surface(chi, vel, params);

    term_surface = -(1/alpha1) * (Lt+L) * sigpow(vel,2-alpha1);
    term_robust = -params.k0*sign(s);

    q = pt_reaching_term(s,params);

    sig_v_neg = sigpow_negative(vel, 1-alpha1, neg_mode, eps_v);

    F = q + params.k1*s;

    term_reaching = -(1/alpha1) * sig_v_neg .* F;

    virtual_accel = term_surface + term_robust + term_reaching;

    J = jacobian_J(eta);
    M = mass_matrix();

    tau_surface = (J') * ((J') \ (M * (J \ term_surface)));
    tau_reaching = (J') * ((J') \ (M * (J \ term_reaching)));
    tau_cmd = (J') * ((J') \ (M * (J \ virtual_accel)));

    out = struct();

    out.s = s;
    out.q = q;
    out.F = F;
    out.sig_v_neg = sig_v_neg;
    out.term_surface = term_surface;
    out.term_reaching = term_reaching;
    out.tau_surface = tau_surface;
    out.tau_reaching = tau_reaching;
    out.tau_cmd = tau_cmd;
end
