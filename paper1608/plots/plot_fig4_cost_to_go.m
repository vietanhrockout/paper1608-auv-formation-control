function fig = plot_fig4_cost_to_go(rl, manifest, params)
    % PLOT_FIG4_COST_TO_GO
    % Paper Fig. 4: long-term cost function (cost-to-go) Chat_i(t) per AUV.
    %
    % *** PROVISIONAL DIAGNOSTIC -- NOT A REPRODUCTION, IN EITHER SENSE ***
    % Wording narrowed per REVIEW_GPT_2026-08-18_R12.md [P1]: an earlier
    % draft called this a "shape-only" reproduction, which overstated the
    % match. BOTH the shape and the scale differ from the paper:
    %   * Paper Fig. 4: monotone rise from zero to THREE DISTINCT positive
    %     plateaus 0.85e8 / 1.4e8 / 2.1e8.
    %   * Here: strongly negative excursion, oscillation, then convergence
    %     to ONE COMMON level ~8.2.
    %
    % On the scale gap (quantified in
    % paper1608/verify/diagnose_stepS1_rl_figure_feasibility.m): the critic
    % is Chat = Wc'*theta_c(chi) with ||Wc||<=delta_c and theta_c a vector
    % of 15 Gaussian RBFs in (0,1], so Cauchy-Schwarz caps |Chat| at
    % delta_c*sqrt(15) = 387.3 -- ~2.2e5x below the paper's smallest
    % plateau, for ANY trajectory. delta_c=100 is this project's own
    % assumed placeholder (Issue N; the paper gives no numeric
    % delta_c/delta_a).
    %
    % CAUSAL SCOPE, stated carefully: that bound makes the assumed delta_c
    % a SUFFICIENT obstruction to reaching 1e8. It does NOT prove delta_c
    % is the only obstruction, and it does NOT show that raising delta_c
    % alone would recover the paper's curves. The assumed reward weights
    % B/R, the basis normalization, the tau_cmd-vs-tau_act reward choice
    % (Issue M) and the learning dynamics are all unexcluded contributors.
    % No delta_c sweep is implied or recommended by this figure.
    %
    % Separately: Chat goes NEGATIVE (min ~ -58). The true cost-to-go is an
    % integral of the Eq.(16) reward r = chi'*B*chi + tau'*R*tau with B=I,
    % R=1e-4*I both PSD, so r>=0 and the true value is non-negative by
    % construction. The negative excursion is therefore genuine
    % approximation invalidity, not a plotting artifact. Projection
    % thrashing (Issue M/K) is CONSISTENT with it but is not established as
    % its unique cause. The zero line is drawn to keep this visible.

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

    sgtitle('Fig. 4 (PROVISIONAL DIAGNOSTIC): Cost-to-Go $\hat{C}_i(t)$ -- qualitative AND quantitative MISMATCH vs. the paper', ...
        'Interpreter', 'latex');

    reserve_bottom_margin(fig, 0.14, 0.05);

    caveat = sprintf(['PROVISIONAL DIAGNOSTIC -- NOT a reproduction. Observed [%.1f, %.1f]: strongly negative, oscillating, then ONE COMMON level ~%.1f. Paper Fig.4: monotone rise from 0 to THREE DISTINCT plateaus 0.85e8/1.4e8/2.1e8 -- BOTH shape and scale differ. ' ...
        'The assumed delta_c=100 is a SUFFICIENT scale obstruction (|Chat| <= delta_c*sqrt(15) = 387.3, Issue N), but is NOT shown to be the only one: assumed reward weights B/R, basis normalization, the tau_cmd/tau_act reward choice (Issue M) and learning dynamics are unexcluded, and nothing here shows raising delta_c alone would recover the paper. ' ...
        'Negative Chat IS invalid for a cost-to-go (Eq.16 reward is PSD so the true value is >=0); projection thrashing (Issue M/K) is consistent with it but not established as its unique cause.'], ...
        min(rl.Chat(:)), max(rl.Chat(:)), mean(rl.Chat(end, :)));
    annotation('textbox', [0.02 0.035 0.96 0.075], 'String', caveat, ...
        'EdgeColor', [0.6 0.2 0.2], 'FontSize', 7.5, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'BackgroundColor', [1 0.96 0.96], 'FitBoxToText', 'off');
    annotation('textbox', [0 0.005 1 0.025], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
