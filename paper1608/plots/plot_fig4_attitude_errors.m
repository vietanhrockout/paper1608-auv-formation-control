function fig = plot_fig4_attitude_errors(res)
    % PLOT_FIG4_ATTITUDE_ERRORS Reproduces Figure 4: Attitude Tracking Errors
    
    fig = figure('Name', 'Figure 4: Attitude Errors', 'Visible', 'off');
    t = res.t;
    X = res.X;
    cfg = nn_config();
    offsets = formation_offsets();
    
    chi_att = zeros(length(t), 3, 3);
    for k = 1:length(t)
        [eta_d0, ~, ~] = reference_1608(t(k));
        [eta_mat, ~, ~, ~, ~] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            chi_att(k, :, i) = (eta_mat(4:6, i) - eta_d0(4:6) - offsets(4:6, i))';
        end
    end
    
    titles = {'\chi_{i4} (\phi-error)', '\chi_{i5} (\theta-error)', '\chi_{i6} (\psi-error)'};
    for dim = 1:3
        subplot(3, 1, dim);
        hold on; grid on; box on;
        plot(t, chi_att(:, dim, 1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'AUV 0');
        plot(t, chi_att(:, dim, 2), 'b-', 'LineWidth', 1.5, 'DisplayName', 'AUV 1');
        plot(t, chi_att(:, dim, 3), 'g-', 'LineWidth', 1.5, 'DisplayName', 'AUV 2');
        ylabel('Error (rad)');
        title(titles{dim});
        if dim == 1, legend('Location', 'best'); end
        if dim == 3, xlabel('Time (s)'); end
    end
end
