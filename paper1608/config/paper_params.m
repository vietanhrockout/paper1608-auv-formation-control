function params = paper_params()
    % PAPER_PARAMS Loads original parameter values from Table 1 of Paper 1608
    % Neurocomputing 677 (2026) 133031, Page 8, Table 1.
    
    params = struct();
    
    % --- Table 1 Core Parameters ---
    params.alpha1  = 1.2;
    params.T1star  = 5;      % Predefined time T1* (seconds)
    params.T2star  = 5;      % Predefined time T2* (seconds)
    params.epsilon = 0.01;
    params.eps0    = 0.8;    % Factor \varepsilon_0 \in (0, 1)
    
    params.b1      = 0.7;
    params.b2      = 10/9;   % 1.1111...
    params.c       = 1.2;
    
    params.zeta1    = 2;      % \varsigma_1
    params.zeta2    = 0.4;    % \varsigma_2
    params.zeta3    = 0.6;    % \varsigma_3
    
    params.k0      = 0.3 * eye(6);  % Robust sliding gain matrix
    params.k1      = 10  * eye(6);  % Sliding surface gain matrix
    params.k2      = 1.0 * eye(6);  % Anti-windup gain matrix
    
    params.lambda_a = 0.04;  % Actor learning rate
    params.lambda_c = 0.3;   % Critic learning rate
    params.c0a      = 2;     % Actor error weight factor
    params.lambda   = 10;    % Discount factor for future cost
    
    params.lc       = 5;     % RBF Gaussian width parameter for Critic
    params.la       = 5;     % RBF Gaussian width parameter for Actor
    
    params.sigma3   = 8;     % Anti-windup predefined-time gain
    params.sigma4   = 8;     % Anti-windup predefined-time gain
    
    % --- Four-Branch Audited Configuration Flags (Step 03 Audit Compliance) ---
    % Issue C: Predefined-time reaching term gain mode ('paper_literal', 'sign_flip_candidate', 'derived_corrected')
    params.sigma_mode = 'paper_literal';
    
    % Issue D: Reference acceleration sign in control law (+1 for dynamics-consistent, -1 for literal Eq. 31)
    params.ref_accel_sign = +1;
    
    % Issue B: Gain formula power (2 for literal T2*, 1 for alternate T1*)
    params.gain_formula_power = 2;
    
    % Issue F: Critic network input mode ('chi' for formation error, 'eta' for absolute position)
    params.critic_input_mode = 'chi';

    % Issue M: Critic reward (Eq. 16) torque argument mode.
    %   'tau_cmd_raw'      : literal reading -- pre-saturation virtual PT-SMC
    %                        command tau_i feeds r_i = chi_i'*B*chi_i + tau_i'*R*tau_i.
    %   'tau_act_saturated': r_i uses the physically-applied, actuator-saturated
    %                        tau_act = sat(tau_cmd, tau_max) (Eq. 2/3's "practical
    %                        input"). Step M.1 (paper1608/verify/diagnose_stepM1_*.m)
    %                        showed 'tau_cmd_raw' inflates r_i (and thus the critic
    %                        Bellman error c_e and update rate dWc/dt) by up to
    %                        7.7e7x at large initial formation error, driving the
    %                        critic weights to the delta_c=100 projection boundary
    %                        within ~1e-5..1e-6 s of simulated time -- the direct
    %                        mechanism behind Issue K's ode45 boundary-crossing
    %                        failure. Phi_i (Eq. 17) is provably independent of
    %                        tau_i, so this mode only rescales r_i/c_e magnitude,
    %                        not the critic update direction.
    params.critic_reward_tau_mode = 'tau_cmd_raw';

    % Issue P: Reaching-law Lambda1^{-1} sign mode in controller_rl.m's F-term
    % (F = q(s)+k1*s+omega_aw), Eq.(31)'s "-sig^{1-alpha1}(v)/alpha1 * F".
    %   'paper_signed'             : literal reading -- multiplies F by
    %                                sig^{1-alpha1}(v) = sign(v)*|v|^{1-alpha1}.
    %                                Step P.1 (paper1608/verify/diagnose_stepP1_*.m)
    %                                proved this algebraically reduces the F-term's
    %                                contribution to ds/dt to -sign(v)*F, NOT -F,
    %                                when substituted into Eq.(23)'s
    %                                Lambda1 = diag{|v|^{alpha1-1}} (UNSIGNED --
    %                                confirmed against the raw PDF text, Eq.23/24,
    %                                which uses |.| bars, no sgn()). This makes the
    %                                dominant reaching-law term's direction flip
    %                                with the arbitrary/chattering sign of a
    %                                near-zero velocity error, instead of robustly
    %                                driving s -> 0.
    %   'proof_consistent_unsigned': multiplies F by |v|^{1-alpha1} (no sign),
    %                                which is the correct algebraic inverse of
    %                                Lambda1 and reduces the F-term's ds/dt
    %                                contribution to exactly -F in all cases
    %                                FOR THE UNREGULARIZED ALGEBRA (Step P.1,
    %                                confirmed via pure scalar test). The
    %                                PRODUCTION implementation in
    %                                controller_rl.m regularizes near v=0
    %                                as (|v|+eps)^{1-alpha1} (eps =
    %                                params.inverse_lambda_eps, default
    %                                1e-6) to avoid a literal singularity --
    %                                this is NOT exactly -F within a few
    %                                orders of magnitude of eps (a second
    %                                independent audit, GPT via the public
    %                                GitHub repo, caught this overclaim;
    %                                see diagnose_stepP1b_epsilon_sensitivity.m
    %                                for how sensitive closed-loop results
    %                                are to the exact eps value).
    % DEFAULT PROMOTED to 'proof_consistent_unsigned' (this session, third pass):
    % Step P.2's closed-loop A/B test (paper1608/verify/diagnose_stepP2_*.m) over
    % a 5s horizon (covering the paper's own claimed T1*=5s) showed AUV0's chi_x,
    % chi_y converge to ~0 and chi_z is monotonically collapsing under this mode,
    % while 'paper_signed' leaves chi completely frozen at its t=0 value for the
    % full 5s. This is a deliberate, evidenced correction of a genuine algebraic
    % inconsistency WITHIN the paper itself (Eq.23's unsigned Lambda1 vs Eq.31's
    % literal signed sig^{1-alpha1}(v) do not cancel per the paper's own stated
    % derivation) -- not a free reproduction-choice like Issue M/N. Per Audit
    % Rule 1 ("never alter core paper equations without explicit, documented
    % theoretical justification"), this documentation plus diagnose_stepP1/P2
    % constitute that justification; user (project owner) explicitly confirmed
    % promoting this to the default. 'paper_signed' remains available for
    % literal-reading comparison/ablation. See Issue P in docs/HANDOFF.md.
    params.inverse_lambda_mode = 'proof_consistent_unsigned';

    % Issue P.1b: regularization epsilon for the above (both branches use
    % (|v|+eps) inside their inverse-power terms near v=0). Swept over
    % {1e-8,1e-7,1e-6,1e-5} in diagnose_stepP1b_epsilon_sensitivity.m;
    % 1e-6 is the value used throughout Steps P.1-P.4 and Phase B.3 and is
    % kept as the default unless that sweep shows a strong reason to change.
    params.inverse_lambda_eps = 1e-6;
end
