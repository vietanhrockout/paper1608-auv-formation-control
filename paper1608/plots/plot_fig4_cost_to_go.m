function fig = plot_fig4_cost_to_go(rl, manifest, params)
    % PLOT_FIG4_COST_TO_GO
    % Paper Fig. 4: long-term cost function (cost-to-go) Chat_i(t) per AUV.
    %
    % *** PROVISIONAL -- NOT A QUANTITATIVE REPRODUCTION ***
    % Established by paper1608/verify/diagnose_stepS1_rl_figure_feasibility.m:
    %   * The paper's Fig. 4 plateaus at 0.85e8 / 1.4e8 / 2.1e8.
    %   * This project's critic is Chat = Wc'*theta_c(chi) with ||Wc||<=delta_c
    %     and theta_c a vector of 15 Gaussian RBFs in (0,1]. Cauchy-Schwarz
    %     therefore caps |Chat| at delta_c*sqrt(15) = 387.3 -- about 2.2e5x
    %     below the paper's smallest plateau -- REGARDLESS of trajectory
    %     quality. Matching Fig. 4's scale would need delta_c >= ~1.1e8.
    %   * delta_c/delta_a are NOT given numeric values anywhere in the paper;
    %     delta_c=100 is this project's own assumed placeholder (Issue N).
    % So the scale gap is a consequence of an ASSUMED parameter, not of a
    % convergence, integrator, or control-law defect. This figure is
    % published as-measured with the gap stated, NOT rescaled to imitate the
    % paper's axis.
    %
    % Second, independent defect shown honestly here: Chat goes NEGATIVE
    % (min ~ -58). The true cost-to-go is an integral of the Eq.(16) reward
    % r = chi'*B*chi + tau'*R*tau with B=I, R=1e-4*I both PSD, so r>=0 and
    % the true cost-to-go is non-negative by construction. A negative Chat
    % is therefore an approximation defect, consistent with Issue M/K
    % (critic weights pinned at the projection boundary and thrashing), not
    % a plotting artifact. The zero line is drawn to make this visible.

    fig = figure('Visible', 'off', 'Position', [100 100 1300 700]);
    colors = {[0.85 0.10 0.10], [0.10 0.45 0.85], [0.10 0.65 0.30]};
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};
    t = rl.t;
    zoom_mask = t <= 15;

    subplot(1, 2, 1); hold on; grid on; box on;
    for i = 1:3
        plot(t, rl.Chat(:, i), 'Color', colors{i}, 'LineWidth', 1.4, 'DisplayName', names{i});
    end
    yline(0, 'k-', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    xlabel('t (s)'); ylabel('$\hat{C}_i(t)$', 'Interpreter', 'latex');
    title('Full horizon [0,100]s');
    legend('Location', 'best', 'FontSize', 8);

    subplot(1, 2, 2); hold on; grid on; box on;
    for i = 1:3
        plot(t(zoom_mask), rl.Chat(zoom_mask, i), 'Color', colors{i}, 'LineWidth', 1.4);
    end
    yline(0, 'k-', 'LineWidth', 1.0);
    xline(5, 'r--', 'T_1^*=5s', 'LabelVerticalAlignment', 'bottom');
    xline(10, 'm--', 'T_1^*+T_2^*=10s', 'LabelVerticalAlignment', 'bottom');
    xlabel('t (s)');
    title('Zoomed transient [0,15]s');

    sgtitle('Fig. 4 (PROVISIONAL): Cost-to-Go $\hat{C}_i(t)$ -- shape only, NOT the paper''s $10^8$ scale', ...
        'Interpreter', 'latex');

    reserve_bottom_margin(fig, 0.14, 0.05);

    caveat = sprintf(['PROVISIONAL: observed range [%.1f, %.1f], settling to a COMMON plateau ~%.1f; ' ...
        'paper Fig.4 rises monotonically from 0 to THREE DISTINCT plateaus 0.85e8/1.4e8/2.1e8. ' ...
        'Scale gap is forced by the ASSUMED delta_c=100 (|Chat| <= delta_c*sqrt(15) = 387.3); matching Fig.4 would need delta_c >= 1.1e8 (Issue N). ' ...
        'Negative Chat is an approximation defect (true cost-to-go >= 0 since the Eq.16 reward is PSD), consistent with Issue M/K.'], ...
        min(rl.Chat(:)), max(rl.Chat(:)), mean(rl.Chat(end, :)));
    annotation('textbox', [0.02 0.035 0.96 0.075], 'String', caveat, ...
        'EdgeColor', [0.6 0.2 0.2], 'FontSize', 7.5, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'BackgroundColor', [1 0.96 0.96], 'FitBoxToText', 'off');
    annotation('textbox', [0 0.005 1 0.025], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
