function verify_step69_plots()
    % VERIFY_STEP69_PLOTS Tests master figure generation function
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    addpath(fullfile(project_root, 'plots'));
    
    generate_all_paper_figures();
    
    plots_dir = fullfile(project_root, 'plots');
    fig_names = {'fig2_3d_trajectory.png', 'fig3_position_errors.png', 'fig4_attitude_errors.png', ...
                 'fig5_control_inputs.png', 'fig6_antiwindup_vars.png', 'fig7_actor_nn_approx.png', ...
                 'fig8_critic_weights.png', 'fig9_comparison.png'};
             
    for k = 1:length(fig_names)
        if ~exist(fullfile(plots_dir, fig_names{k}), 'file')
            error('STEP 69: FAIL - Missing plot image file: %s', fig_names{k});
        end
    end
    
    fprintf('STEP 69: PASS\n');
end
