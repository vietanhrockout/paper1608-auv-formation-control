function generate_all_paper_figures(i_acknowledge_this_is_stale)
    % GENERATE_ALL_PAPER_FIGURES Master script to render and save Figures 2-9
    %
    % *** DO NOT RUN (Phase C.0 gate, GPT audit) ***
    % This entire pipeline predates the detailed Issue I-P audit and its
    % figure numbering does NOT match the actual paper (confirmed against
    % the raw PDF via PyMuPDF page renders -- see handoff.md's Phase C
    % section for the correct mapping):
    %   this file's Fig.4 (attitude errors)   should be Fig.4 = cost-to-go
    %   this file's Fig.5 (control inputs)    should be Fig.5 = actor NN output
    %   this file's Fig.6 (anti-windup vars)  should be Fig.6 = position tracking
    %   this file's Fig.7 (actor NN approx)   should be Fig.7 = formation distances (leader-relative)
    %   this file's Fig.8 (critic weights)    should be Fig.8 = formation tracking error chi
    %   this file's Fig.9 (SMC comparison)    should be Fig.9 = sliding surfaces s_i
    % Only Fig.2 (3D trajectory) happens to already match.
    % This needs a full rewrite against a real Phase C (100s) dataset, not
    % a blind relabeling -- deferred to Phase C.2 (see handoff.md). Calling
    % this function now requires i_acknowledge_this_is_stale=true so it
    % can't be run by accident and mislabeled as the real paper figures.

    if nargin < 1 || isempty(i_acknowledge_this_is_stale) || ~isequal(i_acknowledge_this_is_stale, true)
        error(['generate_all_paper_figures: STALE, figure numbering does not match the ' ...
               'actual paper (see comment block at the top of this file and handoff.md''s ' ...
               'Phase C section). Do not use for real figure reproduction. If you understand ' ...
               'this and want the old placeholder plots anyway, call with ' ...
               'generate_all_paper_figures(true).']);
    end

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    addpath(fullfile(project_root, 'plots'));
    
    mat_path = fullfile(project_root, 'results', 'experiment_results.mat');
    if ~exist(mat_path, 'file')
        fprintf('Running 5-second experiment runner to generate MAT data...\n');
        run_all_experiments(5.0);
    end
    
    data = load(mat_path);
    res4 = data.res4;
    res5 = data.res5;
    
    plots_dir = fullfile(project_root, 'plots');
    
    fprintf('Rendering Figure 2: 3D Trajectory...\n');
    f2 = plot_fig2_3d_trajectory(res4);
    saveas(f2, fullfile(plots_dir, 'fig2_3d_trajectory.png'));
    
    fprintf('Rendering Figure 3: Position Errors...\n');
    f3 = plot_fig3_position_errors(res4);
    saveas(f3, fullfile(plots_dir, 'fig3_position_errors.png'));
    
    fprintf('Rendering Figure 4: Attitude Errors...\n');
    f4 = plot_fig4_attitude_errors(res4);
    saveas(f4, fullfile(plots_dir, 'fig4_attitude_errors.png'));
    
    fprintf('Rendering Figure 5: Control Inputs...\n');
    f5 = plot_fig5_control_inputs(res4);
    saveas(f5, fullfile(plots_dir, 'fig5_control_inputs.png'));
    
    fprintf('Rendering Figure 6: Anti-Windup Variables...\n');
    f6 = plot_fig6_antiwindup_vars(res4);
    saveas(f6, fullfile(plots_dir, 'fig6_antiwindup_vars.png'));
    
    fprintf('Rendering Figure 7: Actor NN Approximation...\n');
    f7 = plot_fig7_actor_nn_approx(res4);
    saveas(f7, fullfile(plots_dir, 'fig7_actor_nn_approx.png'));
    
    fprintf('Rendering Figure 8: Critic Weight Norms...\n');
    f8 = plot_fig8_critic_weights(res4);
    saveas(f8, fullfile(plots_dir, 'fig8_critic_weights.png'));
    
    fprintf('Rendering Figure 9: Performance Comparison...\n');
    f9 = plot_fig9_comparison(res4, res5);
    saveas(f9, fullfile(plots_dir, 'fig9_comparison.png'));
    
    fprintf('All paper figures 2-9 saved successfully in %s!\n', plots_dir);
end
