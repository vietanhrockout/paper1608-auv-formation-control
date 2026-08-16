function [tau_cmd, terms] = controller_rl(eta, eta_dot, t, i_auv, omega_aw_i, Wa_i, params, cfg)
    % CONTROLLER_RL Proposed RL Predefined-Time SMC Controller (Paper 1608 Eq. 31)
    
    if nargin < 7 || isempty(params)
        params = simulation_params();
    end
    if nargin < 8 || isempty(cfg)
        cfg = nn_config();
    end
    
    [chi, vel_err] = formation_error(eta, eta_dot, t, i_auv);
    s = sliding_surface(chi, vel_err, params);
    
    L = gain_matrix_L(chi, params);
    Ltilde = gain_matrix_Ltilde(chi, params);
    
    a1_inv = 1 / params.alpha1;
    sig_v_2minus = sigpow(vel_err, 2 - params.alpha1);
    
    % Term 1: Surface gain derivative term
    term_surface = -a1_inv * (Ltilde + L) * sig_v_2minus;
    
    % Term 2: Robust switching term
    term_robust = -params.k0 * sign(s);
    
    % Term 3: Predefined-time reaching law term + Anti-Windup (Eq. 31 literal placement)
    q_s = pt_reaching_term(s, params);
    F_reach = q_s + params.k1 * s + omega_aw_i;
    inverse_lambda_mode = 'proof_consistent_unsigned'; % matches paper_params.m default (Issue P)
    if isfield(params, 'inverse_lambda_mode') && ~isempty(params.inverse_lambda_mode)
        inverse_lambda_mode = params.inverse_lambda_mode;
    end
    if strcmp(inverse_lambda_mode, 'proof_consistent_unsigned')
        % Issue P: unsigned |v|^{1-alpha1} inverse of Eq.(23)'s Lambda1 =
        % diag{|v|^{alpha1-1}} -- algebraically reduces this term's ds/dt
        % contribution to -F (see diagnose_stepP1_lambda1_inverse_sign.m),
        % vs. the paper-literal sig^{1-alpha1}(v) which reduces to -sign(v)*F.
        inv_lambda1 = (abs(vel_err) + 1e-6) .^ (1 - params.alpha1);
    else
        inv_lambda1 = sigpow_negative(vel_err, 1 - params.alpha1, 'regularized', 1e-6);
    end
    term_reaching = -a1_inv * inv_lambda1 .* F_reach;
    
    % Term 4: Virtual leader reference acceleration feedforward
    [~, ~, eta_d0_ddot] = reference_1608(t);
    term_reference = params.ref_accel_sign * eta_d0_ddot;
    
    % Term 5: Actor RL estimated drift cancellation
    f_rl = actor_output(chi, vel_err, Wa_i, cfg);
    term_rl = -f_rl;
    
    virtual_accel = term_surface + term_robust + term_reaching + term_reference + term_rl;
    
    % Convert to thrust/torque command \tau = J^T M virtual_accel
    J = jacobian_J(eta);
    M = mass_matrix();
    
    tau_cmd = (J') * ((J') \ (M * ((J) \ virtual_accel)));
    
    % Log individual terms for diagnosis
    terms = struct();
    terms.term_surface   = term_surface;
    terms.term_robust    = term_robust;
    terms.term_reaching  = term_reaching;
    terms.term_reference = term_reference;
    terms.term_rl        = term_rl;
    terms.virtual_accel  = virtual_accel;
end
