function fig = plot_fig4_cost_to_go(rl, manifest, params)
    % PLOT_FIG4_COST_TO_GO
    % Paper Fig. 4: long-term cost function (cost-to-go) Chat_i(t) per AUV.
    %
    % *** PROVISIONAL DIAGNOSTIC -- NOT A REPRODUCTION ***
    %
    % REGENERATED under the corrected Eq.(16) reward (Issue M resolved:
    % critic_reward_tau_mode = 'tau_act_saturated'). The behaviour changed
    % qualitatively from the superseded 'tau_cmd_raw' dataset, so the
    % description below was rewritten against the new data rather than
    % carried over.
    %
    % WHAT NOW MATCHES: Chat starts at exactly 0 and settles to THREE
    % DISTINCT, STABLE plateaus -- the same three-level structure the
    % paper's Fig. 4 shows. Under the superseded reward this curve instead
    % swung between roughly -58 and +32 and collapsed to a single common
    % level near +8, so the plateau structure is a genuinely new result.
    %
    % WHAT STILL DOES NOT MATCH:
    %   * SIGN. Chat is non-positive for the whole run (max exactly 0 at
    %     t=0). The paper rises to POSITIVE plateaus. A non-positive
    %     cost-to-go is invalid by construction -- the Eq.(16) reward
    %     r = chi'*B*chi + tau'*R*tau is PSD, so the true value is >= 0.
    %     This is now a clean, systematic sign discrepancy rather than the
    %     chaotic oscillation seen before: a distinct and more diagnosable
    %     open question. It is deliberately NOT patched here; doing so
    %     without evidence would be exactly the symptom-patching this
    %     project forbids.
    %   * SCALE. Ours plateaus at O(1); the paper at O(1e8).
    %   * PER-AUV ORDERING. Ours |Chat|: AUV0 > AUV1 > AUV2. The paper:
    %     AUV2 > AUV0 > AUV1.
    %
    % ON THE SCALE GAP -- the causal story has CHANGED and the wording is
    % narrowed accordingly. The Cauchy-Schwarz bound |Chat| <=
    % delta_c*sqrt(15) = 387.3 still holds, so delta_c=100 remains a
    % SUFFICIENT obstruction to reaching 1e8 (Issue N). But it is now
    % demonstrably NOT the operative one: ||Wc|| peaks at just 14.33, far
    % inside delta_c, so the projection bound is not what limits this run.
    % Whatever sets the O(1) scale here, it is not the projection radius.
    % Assumed reward weights B/R, basis normalization and the learning
    % dynamics remain unexcluded.

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

    sgtitle('Fig. 4 (PROVISIONAL DIAGNOSTIC): Cost-to-Go $\hat{C}_i(t)$ -- plateau STRUCTURE reproduced; SIGN and SCALE do not match', ...
        'Interpreter', 'latex');

    reserve_bottom_margin(fig, 0.14, 0.05);

    caveat = sprintf(['PROVISIONAL DIAGNOSTIC -- NOT a reproduction. Observed [%.1f, 0]: starts at exactly 0, dips through the reaching transient, then settles to THREE DISTINCT STABLE plateaus (AUV0 %.2f, AUV1 %.2f, AUV2 %.2f at t=100s). ' ...
        'The paper also shows three distinct plateaus (0.85e8/1.4e8/2.1e8), so the three-level STRUCTURE is reproduced -- but the SIGN is inverted, the scale differs by ~1e7, and the per-AUV ordering differs. ' ...
        'A non-positive Chat is INVALID for a cost-to-go (Eq.16 reward is PSD): a clean systematic sign discrepancy, deliberately NOT patched. ' ...
        'NOTE: ||Wc|| now peaks at %.2f, far inside delta_c=%.0f -- so unlike the superseded dataset, the projection bound is NOT what limits this run.'], ...
        min(rl.Chat(:)), rl.Chat(end,1), rl.Chat(end,2), rl.Chat(end,3), max(rl.Wc_norm(:)), nn_config().delta_c);
    annotation('textbox', [0.02 0.030 0.96 0.085], 'String', caveat, ...
        'EdgeColor', [0.6 0.2 0.2], 'FontSize', 7.5, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'BackgroundColor', [1 0.96 0.96], 'FitBoxToText', 'off');
    annotation('textbox', [0 0.005 1 0.025], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
