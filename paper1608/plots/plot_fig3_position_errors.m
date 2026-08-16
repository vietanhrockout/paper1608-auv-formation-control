function fig = plot_fig3_position_errors(res)
    % PLOT_FIG3_POSITION_ERRORS Reproduces Figure 3: Position Tracking Errors
    
    fig = figure('Name', 'Figure 3: Position Errors', 'Visible', 'off');
    t = res.t;
    X = res.X;
    cfg = nn_config();
    offsets = formation_offsets();
    
    chi_pos = zeros(length(t), 3, 3);
    for k = 1:length(t)
        [eta_d0, ~, ~] = reference_1608(t(k));
        [eta_mat, ~, ~, ~, ~] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            chi_pos(k, :, i) = (eta_mat(1:3, i) - eta_d0(1:3) - offsets(1:3, i))';
        end
    end
    
    titles = {'\chi_{i1} (x-error)', '\chi_{i2} (y-error)', '\chi_{i3} (z-error)'};
    for dim = 1:3
        subplot(3, 1, dim);
        hold on; grid on; box on;
        plot(t, chi_pos(:, dim, 1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'AUV 0');
        plot(t, chi_pos(:, dim, 2), 'b-', 'LineWidth', 1.5, 'DisplayName', 'AUV 1');
        plot(t, chi_pos(:, dim, 3), 'g-', 'LineWidth', 1.5, 'DisplayName', 'AUV 2');
        ylabel('Error (m)');
        title(titles{dim});
        if dim == 1, legend('Location', 'best'); end
        if dim == 3, xlabel('Time (s)'); end
    end
end
