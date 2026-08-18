function verify_step69_plots()
    % VERIFY_STEP69_PLOTS Verifies the figure-generation pipeline's surface.
    %
    % REWRITTEN during the post-R11 full-project audit. The previous
    % version was STALE and would have failed: it called
    % generate_all_paper_figures() with no arguments and then asserted the
    % existence of seven PNGs from the pre-rewrite pipeline
    % (fig3_position_errors, fig4_attitude_errors, fig5_control_inputs,
    % fig6_antiwindup_vars, fig7_actor_nn_approx, fig8_critic_weights,
    % fig9_comparison) -- all of which were deleted when the plot pipeline
    % was rewritten against the real Phase C dataset (commits e93448b and
    % the Fig.4/5 pass). This was never caught by reviews R8-R11 because
    % the oracle suite cannot run this far (Issue K stalls it at the first
    % integration-level oracle), so this file was effectively dead code.
    %
    % Scope note: this oracle deliberately does NOT re-run
    % generate_all_paper_figures(). Regenerating recomputes per-timestep
    % formation error, sliding surfaces and NN outputs over all 1003
    % samples x 3 AUVs, which takes minutes -- too slow for a suite meant
    % to complete in seconds, and it is already exercised directly
    % whenever figures are produced. What is checked here is that the
    % pipeline's SURFACE is coherent: every plotting entry point exists on
    % the path, and the rendered PNG set matches the current figure
    % mapping exactly, with no stale leftovers from the old numbering.

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(project_root));

    required_fns = { ...
        'generate_all_paper_figures', 'compute_phase_c_series', ...
        'compute_phase_c_rl_series', 'phase_c_provenance_string', ...
        'reserve_bottom_margin', ...
        'plot_fig2_3d_trajectory', 'plot_fig3_planar_trajectory', ...
        'plot_fig6_position_tracking', 'plot_fig7_formation_distances', ...
        'plot_fig8_formation_tracking_error', 'plot_fig9_sliding_surfaces', ...
        'plot_fig4_cost_to_go', 'plot_fig5_actor_nn_output'};
    for k = 1:numel(required_fns)
        if exist(required_fns{k}, 'file') ~= 2
            error('STEP 69: FAIL - missing plotting entry point: %s', required_fns{k});
        end
    end

    plots_dir = fullfile(project_root, 'plots');

    % The six ACCEPTED physical-state figures (REVIEW_GPT_2026-08-17_R11.md).
    accepted = {'fig2_3d_trajectory.png', 'fig3_planar_trajectory.png', ...
                'fig6_position_tracking.png', 'fig7_formation_distances.png', ...
                'fig8_formation_tracking_error.png', 'fig9_sliding_surfaces.png'};
    % The two PROVISIONAL RL figures (Issue M/K/N -- not an accepted reproduction).
    provisional = {'fig4_cost_to_go.png', 'fig5_actor_nn_output.png'};

    for k = 1:numel(accepted)
        if ~exist(fullfile(plots_dir, accepted{k}), 'file')
            error('STEP 69: FAIL - missing accepted figure: %s', accepted{k});
        end
    end
    for k = 1:numel(provisional)
        if ~exist(fullfile(plots_dir, provisional{k}), 'file')
            error('STEP 69: FAIL - missing provisional figure: %s', provisional{k});
        end
    end

    % No stale PNGs from the pre-rewrite numbering may linger, since their
    % filenames encode the WRONG paper figure mapping.
    expected = [accepted, provisional];
    present = dir(fullfile(plots_dir, '*.png'));
    for k = 1:numel(present)
        if ~ismember(present(k).name, expected)
            error(['STEP 69: FAIL - unexpected/stale PNG in plots dir: %s ' ...
                   '(pre-rewrite figure numbering does not match the real paper)'], present(k).name);
        end
    end

    fprintf('STEP 69: PASS (%d accepted + %d provisional figures, no stale PNGs)\n', ...
        numel(accepted), numel(provisional));
end
