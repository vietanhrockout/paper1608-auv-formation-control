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
    % WHAT THE SHAPE DOES AND DOES NOT SHOW. Chat starts at exactly 0 and
    % separates into three distinct levels -- superficially like the
    % paper's three-plateau structure, and a real change from the
    % superseded tau_cmd_raw dataset (which swung between about -58 and
    % +32 and collapsed to a single common level near +8).
    % BUT an earlier version of this header called them 'THREE DISTINCT,
    % STABLE plateaus'. That was WRONG and is withdrawn:
    % REVIEW_GPT_2026-08-25_R17.md measured the late-horizon trend and the
    % curves are still recovering upward over [50,100]s at roughly
    % +0.0105 / +0.0093 / +0.0070 per second -- about +8% of their own
    % value across those 50 s. They are slowly recovering negative tails,
    % NOT converged plateaus. The caption now measures this slope from the
    % data rather than asserting stability by eye.
    %
    % WHAT STILL DOES NOT MATCH:
    %   * SIGN -- and R17 now supplies the MECHANISM. Chat is non-positive
    %     for the whole run (max exactly 0, at t=0). The paper rises to
    %     POSITIVE plateaus. A non-positive cost-to-go is invalid by
    %     construction: the Eq.(16) reward chi'*B*chi + tau'*R*tau is PSD,
    %     so the true return is >= 0 (the state term alone already gives
    %     ~613/257/109 at t=0 for the three vehicles).
    %     ROOT CAUSE (REVIEW_GPT_2026-08-25_R17.md, reproduced locally):
    %     Phi'*theta = -||theta||^2/lambda + theta'*thetadot. During the
    %     fast initial transient the basis-motion term exceeds
    %     ||theta||^2/lambda, so Phi'*theta turns POSITIVE. With Wc(0)=0
    %     and c_e(0)=r(0)>0, dChat/dt(0) = -lambda_c*r(0)*Phi'*theta is
    %     then negative, so the positive immediate cost drives Chat DOWN.
    %     Eq.(20) bounds only ||Wc||, never the sign -- and ||Wc||=14.33
    %     here, far inside delta_c=100, so projection is not involved.
    %     Deliberately NOT patched: negating the series, flipping Eq.(19),
    %     or plotting abs(Chat) would hide a failed value estimate rather
    %     than repair or explain it. See
    %     paper1608/verify/diagnose_stepS2_cost_to_go_validity.m for the
    %     backward-return comparison quantifying how far off it is.
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

    sgtitle('Fig. 4 (PROVISIONAL DIAGNOSTIC): Cost-to-Go $\hat{C}_i(t)$ -- three distinct NEGATIVE levels, still drifting -- an INVALID cost-to-go', ...
        'Interpreter', 'latex');

    reserve_bottom_margin(fig, 0.14, 0.05);

    % Measure the late-horizon trend instead of asserting it. An earlier
    % caption called these 'THREE DISTINCT, STABLE plateaus'; R17 showed
    % that is not supported by the data -- each curve is still recovering
    % upward at ~+0.007..+0.010 /s over [50,100]s (~8% of its own value).
    % Reading the slope from the data keeps the wording honest if the
    % dataset is ever regenerated.
    late = rl.t >= 50;
    slopes = zeros(1,3);
    for q = 1:3
        pf = polyfit(rl.t(late), rl.Chat(late, q), 1);
        slopes(q) = pf(1);
    end
    pct = 100 * (rl.Chat(end,:) - rl.Chat(find(late,1),:)) ./ abs(rl.Chat(find(late,1),:));

    caveat = sprintf(['PROVISIONAL DIAGNOSTIC -- NOT a valid cost-to-go. Observed [%.1f, %.1f]: starts at exactly 0, dips through the reaching transient, then settles into THREE DISTINCT NEGATIVE LEVELS (AUV0 %.2f, AUV1 %.2f, AUV2 %.2f at t=100s). ' ...
        'These are NOT converged plateaus: over [50,100]s each is still recovering upward at %+.4f/%+.4f/%+.4f per second (%+.1f%%/%+.1f%%/%+.1f%% of its own value). ' ...
        'Chat<=0 is INVALID for a cost-to-go (Eq.16 reward is PSD so the true return is >=0; the state term alone already gives ~613/257/109 at t=0). ' ...
        'R17 root-caused it: with Wc(0)=0, once Phi''*theta turns positive during the fast transient, positive cost drives Chat NEGATIVE. Eq.20 bounds only ||Wc||, never the sign. NOT patched -- see REVIEW_GPT_2026-08-25_R17.md.'], ...
        min(rl.Chat(:)), max(rl.Chat(:)), rl.Chat(end,1), rl.Chat(end,2), rl.Chat(end,3), ...
        slopes(1), slopes(2), slopes(3), pct(1), pct(2), pct(3));
    annotation('textbox', [0.02 0.030 0.96 0.085], 'String', caveat, ...
        'EdgeColor', [0.6 0.2 0.2], 'FontSize', 7.5, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'BackgroundColor', [1 0.96 0.96], 'FitBoxToText', 'off');
    annotation('textbox', [0 0.005 1 0.025], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
