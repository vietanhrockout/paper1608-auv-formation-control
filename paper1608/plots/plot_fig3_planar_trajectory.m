function fig = plot_fig3_planar_trajectory(series, manifest, params)
    % PLOT_FIG3_PLANAR_TRAJECTORY
    % Paper Fig. 3: 2D planar (x-y) motion trajectory of the 3 AUVs plus
    % the virtual leader reference path, t in [0,100]s.

    fig = figure('Visible', 'off', 'Position', [100 100 800 700]);
    hold on; grid on; box on; axis equal;

    colors = {[0.85 0.10 0.10], [0.10 0.45 0.85], [0.10 0.65 0.30]};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};

    for i = 1:3
        x = series.eta(:, 1, i); y = series.eta(:, 2, i);
        plot(x, y, 'Color', colors{i}, 'LineWidth', 1.6, 'DisplayName', names{i});
        plot(x(1), y(1), 'o', 'Color', colors{i}, 'MarkerFaceColor', colors{i}, ...
            'MarkerSize', 7, 'HandleVisibility', 'off');
        plot(x(end), y(end), 's', 'Color', colors{i}, 'MarkerFaceColor', 'w', ...
            'MarkerSize', 8, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
    plot(series.eta_d0(:, 1), series.eta_d0(:, 2), 'k--', 'LineWidth', 1.2, ...
        'DisplayName', 'virtual leader reference \eta_{d0}(t)');

    xlabel('x (m)'); ylabel('y (m)');
    title('Fig. 3: 2D Planar (x-y) Trajectory (circle = start, square = end)');
    legend('Location', 'best');
    subtitle(phase_c_provenance_string(manifest, params), 'FontSize', 8, 'Interpreter', 'none');
end
