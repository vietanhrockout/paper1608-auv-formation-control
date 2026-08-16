function fig = plot_fig9_comparison(res4, res5)
    % PLOT_FIG9_COMPARISON Reproduces Figure 9: Comparative Position Tracking Norm (Proposed RL PT-SMC vs Conventional SMC)
    
    fig = figure('Name', 'Figure 9: Performance Comparison', 'Visible', 'off');
    hold on; grid on; box on;
    
    cfg = nn_config();
    offsets = formation_offsets();
    
    % Proposed RL PT-SMC (Exp 4)
    t4 = res4.t;
    err4 = zeros(length(t4), 1);
    for k = 1:length(t4)
        [eta_d0, ~, ~] = reference_1608(t4(k));
        [eta_mat, ~, ~, ~, ~] = unpack_states(res4.X(k, :)', cfg);
        e0 = eta_mat(:, 1) - eta_d0 - offsets(:, 1);
        err4(k) = norm(e0(1:3));
    end
    
    % Conventional SMC (Exp 5)
    t5 = res5.t;
    err5 = zeros(length(t5), 1);
    for k = 1:length(t5)
        [eta_d0, ~, ~] = reference_1608(t5(k));
        eta0 = res5.X(k, 1:6)';
        e0 = eta0 - eta_d0 - offsets(:, 1);
        err5(k) = norm(e0(1:3));
    end
    
    plot(t4, err4, 'r-', 'LineWidth', 2, 'DisplayName', 'Proposed RL PT-SMC');
    plot(t5, err5, 'b--', 'LineWidth', 1.5, 'DisplayName', 'Conventional SMC');
    
    xline(5.0, 'k:', 'LineWidth', 1.2, 'DisplayName', 'Predefined Time T1*');
    
    xlabel('Time (s)');
    ylabel('|| \chi_{0,pos} || (m)');
    title('Figure 9: Position Tracking Error Norm Comparison');
    legend('Location', 'best');
end
