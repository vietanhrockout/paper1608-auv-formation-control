function fig = plot_fig8_critic_weights(res)
    % PLOT_FIG8_CRITIC_WEIGHTS Reproduces Figure 8: Critic Weight Vector Norm Convergence ||W_{ci}||_2
    
    fig = figure('Name', 'Figure 8: Critic Weight Norms', 'Visible', 'off');
    hold on; grid on; box on;
    
    t = res.t;
    X = res.X;
    cfg = nn_config();
    
    Wc_norms = zeros(length(t), 3);
    for k = 1:length(t)
        [~, ~, ~, ~, Wc_mat] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            Wc_norms(k, i) = norm(Wc_mat(:, i));
        end
    end
    
    plot(t, Wc_norms(:, 1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'AUV 0');
    plot(t, Wc_norms(:, 2), 'b-', 'LineWidth', 1.5, 'DisplayName', 'AUV 1');
    plot(t, Wc_norms(:, 3), 'g-', 'LineWidth', 1.5, 'DisplayName', 'AUV 2');
    
    xlabel('Time (s)');
    ylabel('||\hat{w}_{ci}||_2');
    title('Figure 8: Convergence of Critic Weight Vector Norms');
    legend('Location', 'best');
end
