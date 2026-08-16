function fig = plot_fig6_antiwindup_vars(res)
    % PLOT_FIG6_ANTIWINDUP_VARS Reproduces Figure 6: Auxiliary Anti-Windup Variables \varpi_i
    
    fig = figure('Name', 'Figure 6: Anti-Windup States', 'Visible', 'off');
    t = res.t;
    X = res.X;
    cfg = nn_config();
    
    omega_aw_all = zeros(length(t), 6, 3);
    for k = 1:length(t)
        [~, ~, omega_aw_mat, ~, ~] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            omega_aw_all(k, :, i) = omega_aw_mat(:, i)';
        end
    end
    
    titles = {'\varpi_{i1}', '\varpi_{i2}', '\varpi_{i3}', '\varpi_{i4}', '\varpi_{i5}', '\varpi_{i6}'};
    for dim = 1:6
        subplot(3, 2, dim);
        hold on; grid on; box on;
        plot(t, omega_aw_all(:, dim, 1), 'r-', 'LineWidth', 1.2, 'DisplayName', 'AUV 0');
        plot(t, omega_aw_all(:, dim, 2), 'b-', 'LineWidth', 1.2, 'DisplayName', 'AUV 1');
        plot(t, omega_aw_all(:, dim, 3), 'g-', 'LineWidth', 1.2, 'DisplayName', 'AUV 2');
        title(titles{dim});
        if dim >= 5, xlabel('Time (s)'); end
    end
end
