function fig = plot_fig9_sliding_surfaces(series, manifest, params)
    % PLOT_FIG9_SLIDING_SURFACES
    % Paper Fig. 9: sliding surface s_i (6 components per AUV), t in
    % [0,100]s, with a "Predefined time T1*" vertical dashed marker at
    % t=5s (as in the paper's own Fig. 9) and the combined T1*+T2*=10s
    % horizon. Per REVIEW_GPT_2026-08-17_R8/R9: this dataset does NOT
    % show s collapsing to its small neighborhood by the T1* marker the
    % way the paper's own published Fig. 9 does (s is still O(1)-O(10^2)
    % at t=5s here; the zoomed [0,15]s column shows the actual reaching
    % time, ~7.1-7.5s, honestly rather than obscuring it on a 100s axis.

    fig = figure('Visible', 'off', 'Position', [100 100 1300 800]);
    comp_labels = {'x', 'y', 'z', '\phi', '\theta', '\psi'};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};
    t = series.t;
    zoom_mask = t <= 15;

    for i = 1:3
        subplot(3, 2, (i - 1) * 2 + 1); hold on; grid on; box on;
        for comp = 1:6
            plot(t, series.s(:, comp, i), 'LineWidth', 1.0, 'DisplayName', comp_labels{comp});
        end
        xline(5, 'r--', 'HandleVisibility', 'off');
        ylabel(sprintf('%s s', names{i}));
        if i == 1
            title('Full horizon [0,100]s (dashed = T_1^*=5s)');
            legend('Location', 'best', 'FontSize', 7, 'NumColumns', 3);
        end
        if i == 3
            xlabel('t (s)');
        end

        subplot(3, 2, (i - 1) * 2 + 2); hold on; grid on; box on;
        for comp = 1:6
            plot(t(zoom_mask), series.s(zoom_mask, comp, i), 'LineWidth', 1.0);
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

    sgtitle('Fig. 9: Sliding Surface s_i (6 components per AUV)');
    annotation('textbox', [0 0 1 0.03], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
