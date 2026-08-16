function fig = plot_fig5_control_inputs(res)
    % PLOT_FIG5_CONTROL_INPUTS Reproduces Figure 5: Physical Control Forces & Moments
    
    fig = figure('Name', 'Figure 5: Control Inputs', 'Visible', 'off');
    t = res.t;
    X = res.X;
    cfg = nn_config();
    params = paper_params();
    sat_cfg = saturation_config();
    
    tau_act_all = zeros(length(t), 6, 3);
    for k = 1:length(t)
        [eta_mat, nu_mat, omega_aw_mat, Wa_cell, ~] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            eta = eta_mat(:, i);
            nu  = nu_mat(:, i);
            J   = jacobian_J(eta);
            eta_dot = J * nu;
            tau_cmd = controller_rl(eta, eta_dot, t(k), i, omega_aw_mat(:, i), Wa_cell{i}, params, cfg);
            [tau_act, ~] = sat_vector(tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);
            tau_act_all(k, :, i) = tau_act';
        end
    end
    
    titles = {'\tau_1 (N)', '\tau_2 (N)', '\tau_3 (N)', '\tau_4 (N\cdot m)', '\tau_5 (N\cdot m)', '\tau_6 (N\cdot m)'};
    for dim = 1:6
        subplot(3, 2, dim);
        hold on; grid on; box on;
        plot(t, tau_act_all(:, dim, 1), 'r-', 'LineWidth', 1.2, 'DisplayName', 'AUV 0');
        plot(t, tau_act_all(:, dim, 2), 'b-', 'LineWidth', 1.2, 'DisplayName', 'AUV 1');
        plot(t, tau_act_all(:, dim, 3), 'g-', 'LineWidth', 1.2, 'DisplayName', 'AUV 2');
        
        % Add saturation boundary lines
        yline(sat_cfg.tau_max(dim), 'k--', 'LineWidth', 1);
        yline(sat_cfg.tau_min(dim), 'k--', 'LineWidth', 1);
        
        title(titles{dim});
        if dim >= 5, xlabel('Time (s)'); end
    end
end
