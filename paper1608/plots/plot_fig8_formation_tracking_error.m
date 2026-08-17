function fig = plot_fig8_formation_tracking_error(series, manifest, params)
    % PLOT_FIG8_FORMATION_TRACKING_ERROR
    % Paper Fig. 8: formation tracking error chi_i (6 components per AUV),
    % t in [0,100]s. Left column: full horizon. Right column: zoomed
    % [0,15]s transient with T1*=5s and T1*+T2*=10s markers, per
    % REVIEW_GPT_2026-08-17_R8/R9 -- do NOT visually imply chi reached its
    % neighborhood by 5s; the zoomed view shows the actual reaching time
    % honestly instead of hiding it behind full-horizon axis compression.

    fig = figure('Visible', 'off', 'Position', [100 100 1300 800]);
    comp_labels = {'x', 'y', 'z', '\phi', '\theta', '\psi'};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};
    t = series.t;
    zoom_mask = t <= 15;

    for i = 1:3
        subplot(3, 2, (i - 1) * 2 + 1); hold on; grid on; box on;
        for comp = 1:6
            plot(t, series.chi(:, comp, i), 'LineWidth', 1.0, 'DisplayName', comp_labels{comp});
        end
        ylabel(sprintf('%s \\chi', names{i}));
        if i == 1
            title('Full horizon [0,100]s');
            legend('Location', 'best', 'FontSize', 7, 'NumColumns', 3);
        end
        if i == 3
            xlabel('t (s)');
        end

        subplot(3, 2, (i - 1) * 2 + 2); hold on; grid on; box on;
        for comp = 1:6
            plot(t(zoom_mask), series.chi(zoom_mask, comp, i), 'LineWidth', 1.0);
        end
        xline(5, 'r--', 'T_1^*=5s', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
        xline(10, 'm--', 'T_1^*+T_2^*=10s', 'LabelVerticalAlignment', 'bottom', 'HandleVisibility', 'off');
        if i == 1
            title('Zoomed transient [0,15]s (reaching-deadline markers)');
        end
        if i == 3
            xlabel('t (s)');
        end
    end

    sgtitle('Fig. 8: Formation Tracking Error \chi_i (6 components per AUV)');
    annotation('textbox', [0 0 1 0.03], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
