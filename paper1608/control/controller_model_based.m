function [tau_cmd, terms] = controller_model_based(eta, eta_dot, t, i_auv, params)
    % CONTROLLER_MODEL_BASED Predefined-Time SMC using true drift f_i (Eq. 25)
    
    if nargin < 5 || isempty(params)
        params = simulation_params();
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
    
    % Term 3: Predefined-time reaching law term
    q_s = pt_reaching_term(s, params);
    sig_v_neg = sigpow_negative(vel_err, 1 - params.alpha1, 'regularized', 1e-6);
    term_reaching = -a1_inv * sig_v_neg .* (q_s + params.k1 * s);
    
    % Term 4: Virtual leader reference acceleration feedforward
    [~, ~, eta_d0_ddot] = reference_1608(t);
    term_reference = params.ref_accel_sign * eta_d0_ddot;
    
    % Term 5: True model drift cancellation
    f_val = f_true_drift(eta, eta_dot);
    term_model = -f_val;
    
    virtual_accel = term_surface + term_robust + term_reaching + term_reference + term_model;
    
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
    terms.term_model     = term_model;
    terms.virtual_accel  = virtual_accel;
end
