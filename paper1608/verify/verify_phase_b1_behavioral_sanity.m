function verify_phase_b1_behavioral_sanity()
    % VERIFY_PHASE_B1_BEHAVIORAL_SANITY Phase B.1 Closed-Loop Behavioral Sanity Test (15 s)
    % Evaluates 15s simulation of Exp4 (Proposed RL PT-SMC), checks envelope decay & bounds.
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    fprintf('=== PHASE B.1: Running 15-Second Closed-Loop Behavioral Sanity Simulation ===\n');
    res = exp4_rl_pts_mc(15.0);
    
    t_out = res.t;
    X_out = res.X;
    cfg = nn_config();
    sat_cfg = saturation_config();
    params = res.params;
    
    % 1. Solver completion check
    if isempty(t_out) || t_out(end) < 14.9
        error('PHASE B.1: FAIL - Closed-loop simulation terminated early');
    end
    if any(isnan(X_out(:))) || any(isinf(X_out(:)))
        error('PHASE B.1: FAIL - Closed-loop simulation state contains NaN or Inf');
    end
    
    N_steps = length(t_out);
    % Subsample grid (max 300 evaluation steps) for efficient post-processing
    step_stride = max(1, floor(N_steps / 300));
    check_indices = 1:step_stride:N_steps;
    
    E_chi = zeros(length(check_indices), 1);
    E_upsilon = zeros(length(check_indices), 1);
    E_s = zeros(length(check_indices), 1);
    t_check = t_out(check_indices);
    
    max_tau_cmd_force  = 0;
    max_tau_cmd_moment = 0;
    max_tau_act_force  = 0;
    max_tau_act_moment = 0;
    max_delta_tau      = 0;
    
    for idx_i = 1:length(check_indices)
        k = check_indices(idx_i);
        t_k = t_out(k);
        X_k = X_out(k, :)';
        [eta_m, nu_m, omega_aw_mat, Wa_l, Wc_m] = unpack_states(X_k, cfg);
        
        e_chi_k = zeros(3, 1);
        e_ups_k = zeros(3, 1);
        e_s_k   = zeros(3, 1);
        
        for i = 1:3
            eta = eta_m(:, i);
            nu  = nu_m(:, i);
            J   = jacobian_J(eta);
            eta_dot = J * nu;
            
            [chi, vel_err] = formation_error(eta, eta_dot, t_k, i);
            s = sliding_surface(chi, vel_err, params);
            
            e_chi_k(i) = max(abs(chi));
            e_ups_k(i) = max(abs(vel_err));
            e_s_k(i)   = max(abs(s));
            
            % 2. Weight bound projection compliance
            if norm(Wc_m(:, i)) > cfg.delta_c + 1e-4
                error('PHASE B.1: FAIL - Critic weight norm exceeded delta_c at t=%.2f', t_k);
            end
            for j = 1:6
                if norm(Wa_l{i}(:, j)) > cfg.delta_a + 1e-4
                    error('PHASE B.1: FAIL - Actor weight norm exceeded delta_a at t=%.2f', t_k);
                end
            end
            
            % 3. Actuator force/torque physical saturation compliance & statistics
            tau_cmd = controller_rl(eta, eta_dot, t_k, i, omega_aw_mat(:, i), Wa_l{i}, params, cfg);
            [tau_act, dtau] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
            
            % Explicit saturation assertions
            if any(abs(tau_act(1:3)) > 150.0 + 1e-5)
                error('PHASE B.1: FAIL - Actuator force limit 150 N exceeded at t=%.2f', t_k);
            end
            if any(abs(tau_act(4:6)) > 30.0 + 1e-5)
                error('PHASE B.1: FAIL - Actuator moment limit 30 N*m exceeded at t=%.2f', t_k);
            end
            
            max_tau_cmd_force  = max(max_tau_cmd_force, max(abs(tau_cmd(1:3))));
            max_tau_cmd_moment = max(max_tau_cmd_moment, max(abs(tau_cmd(4:6))));
            max_tau_act_force  = max(max_tau_act_force, max(abs(tau_act(1:3))));
            max_tau_act_moment = max(max_tau_act_moment, max(abs(tau_act(4:6))));
            max_delta_tau      = max(max_delta_tau, max(abs(dtau)));
        end
        
        E_chi(idx_i)     = max(e_chi_k);
        E_upsilon(idx_i) = max(e_ups_k);
        E_s(idx_i)       = max(e_s_k);
    end
    
    % Print Progression Table
    fprintf('\nFormation Error Envelopes Progression Over Time:\n');
    fprintf('  t (s)    E_chi(t) [pos/att]    E_upsilon(t) [vel]    E_s(t) [sliding]\n');
    fprintf('  -------------------------------------------------------------------\n');
    
    sample_times = [0.0, 1.0, 3.0, 5.0, 10.0, 15.0];
    for st = sample_times
        [~, idx] = min(abs(t_check - st));
        fprintf('  %5.1f       %12.4f          %12.4f       %12.4f\n', ...
            t_check(idx), E_chi(idx), E_upsilon(idx), E_s(idx));
    end
    fprintf('  -------------------------------------------------------------------\n');
    
    % Print Actuator Statistics
    fprintf('\nActuator Saturation Statistics:\n');
    fprintf('  Max tau_cmd Force : %8.2f N  |  Max tau_act Force : %8.2f N\n', max_tau_cmd_force, max_tau_act_force);
    fprintf('  Max tau_cmd Moment: %8.2f Nm |  Max tau_act Moment: %8.2f Nm\n', max_tau_cmd_moment, max_tau_act_moment);
    fprintf('  Max delta_tau     : %8.2f\n', max_delta_tau);
    
    % Tail statistics (t >= 13.5 s)
    tail_mask = t_check >= 13.5;
    tail_chi = median(E_chi(tail_mask));
    tail_ups = median(E_upsilon(tail_mask));
    tail_s   = median(E_s(tail_mask));
    fprintf('  Tail Medians (t >= 13.5s): E_chi=%.4f, E_upsilon=%.4f, E_s=%.4f\n', tail_chi, tail_ups, tail_s);
    
    % 4. Non-divergence envelope decay check
    if E_chi(end) > E_chi(1)
        error('PHASE B.1: FAIL - Formation tracking error diverged over 15s');
    end
    
    fprintf('\nPHASE B.1: PASS (15s ODE integration finite, weight & actuator bounds satisfied, tracking error non-divergent)\n');
end
