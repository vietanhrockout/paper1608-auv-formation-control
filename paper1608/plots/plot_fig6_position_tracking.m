function fig = plot_fig6_position_tracking(series, manifest, params)
    % PLOT_FIG6_POSITION_TRACKING
    % Paper Fig. 6: Position tracking response (x,y,z) per AUV vs. its
    % desired position eta_d0(t)+eta_l0i, t in [0,100]s. 3x3 grid: rows =
    % x/y/z components, columns = AUV0/AUV1/AUV2.

    fig = figure('Visible', 'off', 'Position', [100 100 1300 750]);
    labels = {'x (m)', 'y (m)', 'z (m)'};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};
    t = series.t;

    for i = 1:3
        desired = series.eta_d0(:, 1:3) + series.offsets(1:3, i).';
        for comp = 1:3
            subplot(3, 3, (comp - 1) * 3 + i);
            % REVIEW_GPT_2026-08-17_R10.md P1: draw "actual" first, then the
            % neutral dashed "desired" reference LAST (on top) so it stays
            % visible instead of being fully covered once tracking converges.
            plot(t, series.eta(:, comp, i), 'b-', 'LineWidth', 1.2, 'DisplayName', 'actual'); hold on;
            plot(t, desired(:, comp), '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.4, 'DisplayName', 'desired');
            grid on; box on;
            if comp == 1
                title(names{i});
            end
            if i == 1
                ylabel(labels{comp});
            end
            if comp == 3
                xlabel('t (s)');
            end
            if comp == 1 && i == 1
                legend('Location', 'best', 'FontSize', 7);
            end
        end
    end

    sgtitle('Fig. 6: Position Tracking Response (x,y,z) per AUV vs. Desired Position');
    annotation('textbox', [0 0 1 0.03], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
