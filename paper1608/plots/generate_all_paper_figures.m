function generate_all_paper_figures()
    % GENERATE_ALL_PAPER_FIGURES Master script to render and save Figures 2-9
    
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
