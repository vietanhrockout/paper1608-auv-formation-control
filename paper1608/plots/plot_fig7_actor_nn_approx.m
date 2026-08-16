function fig = plot_fig7_actor_nn_approx(res)
    % PLOT_FIG7_ACTOR_NN_APPROX Reproduces Figure 7: Actor RBF NN Drift Approximation (f_iRL vs f_itrue)
    
    fig = figure('Name', 'Figure 7: Actor NN Approximation', 'Visible', 'off');
    t = res.t;
    X = res.X;
    cfg = nn_config();
    
    f_rl_auv0 = zeros(length(t), 6);
    f_true_auv0 = zeros(length(t), 6);
    
    for k = 1:length(t)
        [eta_mat, nu_mat, ~, Wa_cell, ~] = unpack_states(X(k, :)', cfg);
        eta = eta_mat(:, 1);
        nu  = nu_mat(:, 1);
        J   = jacobian_J(eta);
        eta_dot = J * nu;
        
        [chi, vel_err] = formation_error(eta, eta_dot, t(k), 1);
        f_rl_auv0(k, :) = actor_output(chi, vel_err, Wa_cell{1}, cfg)';
        f_true_auv0(k, :) = f_true_drift(eta, eta_dot)';
    end
    
    titles = {'f_{01}', 'f_{02}', 'f_{03}', 'f_{04}', 'f_{05}', 'f_{06}'};
    for dim = 1:6
        subplot(3, 2, dim);
        hold on; grid on; box on;
        plot(t, f_true_auv0(:, dim), 'k-', 'LineWidth', 1.5, 'DisplayName', 'True Drift f_{true}');
        plot(t, f_rl_auv0(:, dim), 'r--', 'LineWidth', 1.5, 'DisplayName', 'Actor NN f_{RL}');
        title(titles{dim});
        if dim == 1, legend('Location', 'best'); end
        if dim >= 5, xlabel('Time (s)'); end
    end
end
