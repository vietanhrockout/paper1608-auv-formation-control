function fig = plot_fig5_actor_nn_output(rl, manifest, params)
    % PLOT_FIG5_ACTOR_NN_OUTPUT
    % Paper Fig. 5: actor RBF network output theta_a(xbar_a), paper y-range
    % [0,1.5] (recorded in docs/HANDOFF.md from a direct render of the source PDF).
    %
    % *** PROVISIONAL *** -- Figs. 4-5 remain outside the accepted
    % physical-state figure set (see REVIEW_GPT_2026-08-17_R9/R11.md).
    % REGENERATED under the corrected Eq.(16) reward (Issue M resolved:
    % critic_reward_tau_mode = 'tau_act_saturated'). Note the behaviour of
    % f_RL changed materially: under the superseded 'tau_cmd_raw' reward it
    % drifted linearly negative with no sign of settling, whereas it now
    % rises and plateaus. Unlike Fig. 4, Fig. 5 has NO scale
    % obstruction: paper1608/verify/diagnose_stepS1_rl_figure_feasibility.m
    % confirms the individual RBF activations are in (0,1] by construction
    % (observed max exactly 1.000000), so the paper's [0,1.5] axis
    % accommodates them directly.
    %
    % TWO READINGS of "actor network output", both shown rather than
    % silently picking one:
    %   LEFT  -- theta_a(xbar_aij): the RBF BASIS activations themselves
    %            (25 nodes). This is the literal reading of the paper's own
    %            "theta_a(xbar_a)" label and the one whose range matches the
    %            paper's [0,1.5] axis.
    %   RIGHT -- f_RL = Wa'*theta_a: the actor NETWORK output, i.e. the
    %            estimated drift actually fed into the control law (Eq. 32).
    %            Observed |f_RL| ~ 11.4 under the corrected reward, which
    %            would NOT fit a [0,1.5] axis -- evidence that the paper's
    %            Fig. 5 is the basis-activation reading, not this one. The
    %            exact figure is printed from the data in the caption, so it
    %            cannot go stale when the dataset is regenerated.
    %
    % REPRODUCTION ASSUMPTION: the actor RBF is defined per DOF (input
    % xbar_aij = [chi_ij, upsilon_ij]), so a Fig. 5 rendering must select
    % one DOF; the paper does not state which. rl.actor_dof records the
    % choice (default 3 = heave/z, the largest-initial-error channel).

    dof_names = {'x', 'y', 'z', '\phi', '\theta', '\psi'};
    dof_label = dof_names{rl.actor_dof};

    fig = figure('Visible', 'off', 'Position', [100 100 1300 800]);
    names = {'AUV0 (leader)', 'AUV1 (follower)', 'AUV2 (follower)'};
    comp_labels = {'x', 'y', 'z', '\phi', '\theta', '\psi'};
    t = rl.t;

    for i = 1:3
        subplot(3, 2, (i - 1) * 2 + 1); hold on; grid on; box on;
        plot(t, rl.theta_a(:, :, i), 'LineWidth', 0.7);
        ylim([0 1.5]);
        ylabel(sprintf('%s\n\\theta_a', names{i}));
        if i == 1
            title(sprintf('Actor RBF basis activations \\theta_a (25 nodes), DOF %s -- paper axis [0,1.5]', dof_label));
        end
        if i == 3
            xlabel('t (s)');
        end

        subplot(3, 2, (i - 1) * 2 + 2); hold on; grid on; box on;
        for comp = 1:6
            plot(t, rl.f_rl(:, comp, i), 'LineWidth', 0.9, 'DisplayName', comp_labels{comp});
        end
        ylabel('f_{RL}');
        if i == 1
            title('Actor network output f_{RL}=W_a^T\theta_a (6 DOF) -- different quantity, wider range');
            legend('Location', 'best', 'FontSize', 6, 'NumColumns', 3);
        end
        if i == 3
            xlabel('t (s)');
        end
    end

    sgtitle('Fig. 5 (PROVISIONAL): Actor RBF Output -- both readings of "actor output" shown');

    reserve_bottom_margin(fig, 0.12, 0.03);

    cfg_a = nn_config();
    caveat = sprintf(['PROVISIONAL (Issue M/K), regenerated under the corrected Eq.16 reward (tau_act_saturated). LEFT: RBF activations, range (0,1] by construction -- fits the paper''s [0,1.5] axis; they freeze once chi/upsilon converge (constant RBF input). ' ...
        'RIGHT: actor network output f_RL, observed max|f_RL|=%.2f -- would not fit [0,1.5]. Under the SUPERSEDED tau_cmd_raw reward this drifted linearly negative with no sign of settling; it now rises and visibly PLATEAUS (AUV1 and AUV2 flatten before t=100s; AUV0 is still curving over at the horizon). ' ...
        'max ||Wa||_F = %.4f over the run, well inside delta_a = %.0f. DOF %s for the basis panels is a reproduction assumption (paper does not state which DOF).'], ...
        max(abs(rl.f_rl(:))), max(rl.Wa_norm(:)), cfg_a.delta_a, dof_label);
    annotation('textbox', [0.02 0.03 0.96 0.065], 'String', caveat, ...
        'EdgeColor', [0.6 0.2 0.2], 'FontSize', 7.5, 'HorizontalAlignment', 'center', ...
        'Interpreter', 'none', 'BackgroundColor', [1 0.96 0.96], 'FitBoxToText', 'off');
    annotation('textbox', [0 0.004 1 0.022], 'String', phase_c_provenance_string(manifest, params), ...
        'EdgeColor', 'none', 'FontSize', 8, 'HorizontalAlignment', 'center', 'Interpreter', 'none');
end
