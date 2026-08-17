function fig = plot_fig2_3d_trajectory(series, manifest, params)
    % PLOT_FIG2_3D_TRAJECTORY
    % Paper Fig. 2: 3D operational trajectory of the 3 AUVs (leader +
    % 2 followers) plus the virtual leader reference path, t in [0,100]s.

    fig = figure('Visible', 'off', 'Position', [100 100 900 700]);
    hold on; grid on; box on;

    colors = {[0.85 0.10 0.10], [0.10 0.45 0.85], [0.10 0.65 0.30]};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};

    for i = 1:3
        x = series.eta(:, 1, i); y = series.eta(:, 2, i); z = series.eta(:, 3, i);
        plot3(x, y, z, 'Color', colors{i}, 'LineWidth', 1.6, 'DisplayName', names{i});
        plot3(x(1), y(1), z(1), 'o', 'Color', colors{i}, 'MarkerFaceColor', colors{i}, ...
            'MarkerSize', 7, 'HandleVisibility', 'off');
        plot3(x(end), y(end), z(end), 's', 'Color', colors{i}, 'MarkerFaceColor', 'w', ...
            'MarkerSize', 8, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
    plot3(series.eta_d0(:, 1), series.eta_d0(:, 2), series.eta_d0(:, 3), 'k--', ...
        'LineWidth', 1.2, 'DisplayName', 'virtual leader reference \eta_{d0}(t)');

    xlabel('x (m)'); ylabel('y (m)'); zlabel('z (m)');
    title('Fig. 2: 3D Operational Trajectory (circle = start, square = end)');
    legend('Location', 'best');
    view(-35, 20);
    subtitle(phase_c_provenance_string(manifest, params), 'FontSize', 8, 'Interpreter', 'none');
end
