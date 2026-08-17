function fig = plot_fig7_formation_distances(series, manifest, params)
    % PLOT_FIG7_FORMATION_DISTANCES
    % Paper Fig. 7: formation distance (relative offset components)
    % between each follower and the LEADER -- computed as the actual
    % physical eta_i(t) - eta_1(t) (AUV0 is the leader, index 1 per
    % formation_offsets.m convention), NOT the controller's virtual-
    % reference-relative chi. Per Step L.3a / REVIEW_GPT_2026-08-17_R8-R9
    % condition #3: this must be the real leader-relative distance, with
    % the configured formation offset shown as the convergence target.
    % t in [0,100]s, x/y/z components only (attitude offsets are all 0).

    fig = figure('Visible', 'off', 'Position', [100 100 1100 750]);
    labels = {'x (m)', 'y (m)', 'z (m)'};
    t = series.t;
    colors = {[0.10 0.45 0.85], [0.10 0.65 0.30]};
    names = {'AUV1 - AUV0 (actual)', 'AUV2 - AUV0 (actual)'};

    target_color = [0.3 0.3 0.3];
    for comp = 1:3
        subplot(3, 1, comp); hold on; grid on; box on;
        % REVIEW_GPT_2026-08-17_R10.md P1: draw actual curves first, then
        % ALL target ylines afterward in a neutral gray (distinct from
        % every AUV color) so the dashed target stays visible on top even
        % after the actual curve converges onto it.
        for i = 2:3
            plot(t, series.leader_rel(:, comp, i), 'Color', colors{i - 1}, ...
                'LineWidth', 1.4, 'DisplayName', names{i - 1});
        end
        for i = 2:3
            yline(series.offsets(comp, i), '--', 'Color', target_color, ...
                'LineWidth', 1.4, 'HandleVisibility', 'off');
        end
        ylabel(labels{comp});
        if comp == 1
            title('Fig. 7: Formation Distance (Leader-Relative) vs. Configured Offset (gray dashed)');
            legend('Location', 'best', 'FontSize', 8);
        end
        if comp == 3
            xlabel('t (s)');
        end
    end

    annotation('textbox', [0 0 1 0.03], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
