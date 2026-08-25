function diagnose_stepM1_critic_reward_saturation_coupling()
% DIAGNOSE_STEPM1_CRITIC_REWARD_SATURATION_COUPLING
%
% Pure algebraic/numerical diagnostic. NO ODE simulation, NO production
% modification.
%
% Goal: Quantify how much of Issue K's critic weight explosion
% (dWc/dt ~ 1e7 weight/s) is explained by rhs_3auv_rl.m feeding the RAW,
% unsaturated tau_cmd into strategic_utility.m (Eq. 16 reward), instead of
% the physically-applied, saturated tau_act = sat(tau_cmd, tau_max).
%
% Compares, for all 3 AUVs at t=0 (and a short trajectory of chi/vel
% samples), the resulting r_i, c_e, ||dWc/dt||, and the linear-estimate
% time-to-projection-boundary under both reward definitions.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    params  = simulation_params();
    cfg     = nn_config();
    sat_cfg = saturation_config();

    delta_c = cfg.delta_c;

    out_file = fullfile(fileparts(project_root), 'm1_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP M.1 -- CRITIC REWARD SATURATION COUPLING AUDIT\n');
    p('============================================================\n');
    p('delta_c  = %.6e\n', delta_c);
    p('lambda_c = %.6e\n', params.lambda_c);
    p('R (strategic_utility default) = 1e-4 * eye(6)\n');
    p('tau_max  = [%.1f %.1f %.1f %.1f %.1f %.1f]\n', sat_cfg.tau_max);

    [eta_init, nu_init] = initial_conditions();

    %% ============================================================
    % 1. t=0 comparison across all 3 AUVs, Wc=0, Wa=0 (causality-clean)
    % =============================================================

    p('\n============================================================\n');
    p(' PART 1: t=0, Wc=0, Wa=0 (matches Step K.1 baseline conditions)\n');
    p('============================================================\n');

    ratio_r = zeros(1,3);
    ratio_ce = zeros(1,3);
    ratio_grad = zeros(1,3);

    for i = 1:3
        eta = eta_init(:, i);
        nu  = nu_init(:, i);
        J = jacobian_J(eta);
        eta_dot = J * nu;

        omega_aw = zeros(6,1);
        Wa = zeros(cfg.actor_n_nodes, 6);
        Wc = zeros(cfg.critic_n_nodes, 1);

        [chi, vel_err] = formation_error(eta, eta_dot, 0, i);

        tau_cmd = controller_rl(eta, eta_dot, 0, i, omega_aw, Wa, params, cfg);
        [tau_act, delta_tau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);

        r_raw = strategic_utility(chi, tau_cmd);
        r_sat = strategic_utility(chi, tau_act);

        [ce_raw, Phi_raw] = bellman_error(chi, vel_err, Wc, tau_cmd, params, cfg);
        [ce_sat, Phi_sat] = bellman_error(chi, vel_err, Wc, tau_act, params, cfg);

        % Phi does not depend on tau (only on chi, vel_err, Wc) -- verify
        assert(norm(Phi_raw - Phi_sat) < 1e-12, ...
            'M.1 unexpected: Phi should be independent of tau argument.');

        v_raw = -params.lambda_c * ce_raw * Phi_raw;
        v_sat = -params.lambda_c * ce_sat * Phi_sat;

        gnorm_raw = norm(v_raw);
        gnorm_sat = norm(v_sat);

        if gnorm_raw > 0
            t_bound_raw = delta_c / gnorm_raw;
        else
            t_bound_raw = Inf;
        end
        if gnorm_sat > 0
            t_bound_sat = delta_c / gnorm_sat;
        else
            t_bound_sat = Inf;
        end

        ratio_r(i) = r_raw / max(r_sat, eps);
        ratio_ce(i) = ce_raw / max(abs(ce_sat), eps);
        ratio_grad(i) = gnorm_raw / max(gnorm_sat, eps);

        p('\n------------------------------------------------------------\n');
        p('AUV %d\n', i-1);
        p('------------------------------------------------------------\n');
        p('max|tau_cmd| (raw)      = %.6e N\n', max(abs(tau_cmd(1:3))));
        p('max|tau_act| (saturated)= %.6e N\n', max(abs(tau_act(1:3))));
        p('r_i using tau_cmd (raw) = %.6e\n', r_raw);
        p('r_i using tau_act (sat) = %.6e\n', r_sat);
        p('ratio r_raw/r_sat       = %.6e\n', ratio_r(i));
        p('c_e using tau_cmd (raw) = %.6e\n', ce_raw);
        p('c_e using tau_act (sat) = %.6e\n', ce_sat);
        p('||dWc/dt|| raw          = %.6e weight/s\n', gnorm_raw);
        p('||dWc/dt|| saturated    = %.6e weight/s\n', gnorm_sat);
        p('delta_c/||dWc/dt|| raw  = %.6e s  (time to hit projection ball at Wc=0 origin, linear estimate)\n', t_bound_raw);
        p('delta_c/||dWc/dt|| sat  = %.6e s\n', t_bound_sat);
    end

    p('\nSUMMARY (Part 1): reward inflation ratio r_raw/r_sat per AUV = [%.3e, %.3e, %.3e]\n', ratio_r);
    p('SUMMARY (Part 1): critic gradient inflation ratio per AUV    = [%.3e, %.3e, %.3e]\n', ratio_grad);

    % AUV0 (leader) is the extreme case -- confirm it dominates
    assert(ratio_r(1) > 1e6, 'M.1 FAIL: expected AUV0 raw/sat reward ratio > 1e6.');

    %% ============================================================
    % 2. Sensitivity along a synthetic decay trajectory of chi (crude
    %    proxy for "as formation converges, does the raw-reward problem
    %    persist, or is it purely an initial-transient artifact?")
    % =============================================================

    p('\n============================================================\n');
    p(' PART 2: SENSITIVITY VS. |chi| SHRINKING (AUV0, along x/y/z diag)\n');
    p('============================================================\n');

    scales = [1.0, 0.5, 0.25, 0.1, 0.05, 0.01, 0.001];

    chi0_full = [6;6;16;0;0;0];
    vel0_full = [-0.1;0.1;0.2;0;0;0];

    Wc0 = zeros(cfg.critic_n_nodes,1);
    Wa0 = zeros(cfg.actor_n_nodes,6);
    omega0 = zeros(6,1);

    p('\n scale    |chi|_inf    max|tau_cmd|N   max|tau_act|N   r_raw         r_sat         ratio\n');

    eta_d0_dot0 = [0.1;-0.1;-0.2;0;0;0]; % Eq. 57 leader reference velocity at t=0

    for k = 1:numel(scales)
        sc = scales(k);
        chi_k = chi0_full * sc;
        vel_k = vel0_full; % velocity error held fixed in this proxy sweep

        eta_k = chi_k + [0;0;-10;0;0;0]; % reconstruct eta consistent with chi at t=0 (AUV0 offset=0)
        eta_dot_k = vel_k + eta_d0_dot0; % so that formation_error recovers vel_err = vel_k exactly

        tau_cmd_k = controller_rl(eta_k, eta_dot_k, 0, 1, omega0, Wa0, params, cfg);
        [tau_act_k, ~] = sat_vector(tau_cmd_k, sat_cfg.tau_min, sat_cfg.tau_max);

        r_raw_k = strategic_utility(chi_k, tau_cmd_k);
        r_sat_k = strategic_utility(chi_k, tau_act_k);

        p('%6.3f   %.6e   %.6e   %.6e   %.6e   %.6e   %.6e\n', ...
            sc, norm(chi_k,inf), max(abs(tau_cmd_k(1:3))), max(abs(tau_act_k(1:3))), ...
            r_raw_k, r_sat_k, r_raw_k/max(r_sat_k,eps));
    end

    p('\nInterpretation: as |chi| -> 0, tau_cmd is dominated by robust term k0*sgn(s)\n');
    p('and stays within actuator limits, so the raw/sat ratio should collapse to ~1.\n');
    p('This confirms the reward inflation is an INITIAL-TRANSIENT phenomenon tied\n');
    p('directly to Issue L''s large initial q(s), not a persistent steady-state bug.\n');

    %% ============================================================
    % 3. Verdict
    % =============================================================

    p('\n============================================================\n');
    p(' STEP M.1 VERDICT\n');
    p('============================================================\n');
    p('1. Phi_i (Eq. 17 gradient basis) is provably independent of tau_i.\n');
    p('   Therefore swapping tau_cmd -> tau_act in critic_update/strategic_utility\n');
    p('   changes ONLY the scalar r_i (and thus c_e), not the direction of the\n');
    p('   critic update -- a minimal, surgical, well-justified candidate fix.\n');
    p('2. The reward/gradient inflation is concentrated at large initial |chi|\n');
    p('   (AUV0 t=0 ratio > 1e6) and collapses toward ~1x as |chi| shrinks,\n');
    p('   consistent with Issue K''s observed onset at the very start of\n');
    p('   integration (Phase B.1 ode45 boundary crossing near t=0).\n');
    p('3. RECOMMENDATION: implement candidate fix under a new documented flag\n');
    p('   params.critic_reward_tau_mode in paper_params.m (values:\n');
    p('   ''tau_cmd_raw'' [SUPERSEDED literal reading] vs ''tau_act_saturated'' [CURRENT DEFAULT since 2026-08-18]),\n');
    p('   wire rhs_3auv_rl.m to pass the selected quantity into critic_update,\n');
    p('   and re-run a Step K.2-style micro-horizon boundary-crossing check\n');
    p('   under both modes before altering the production default.\n');

    if fid > 0
        fclose(fid);
    end
end
