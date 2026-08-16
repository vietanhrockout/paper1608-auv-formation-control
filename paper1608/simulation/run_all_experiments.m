function run_all_experiments(t_final)
    % RUN_ALL_EXPERIMENTS Executes Experiments 0 through 5 and saves MAT file
    
    if nargin < 1 || isempty(t_final)
        t_final = 20.0;
    end
    
    fprintf('Running Experiment 0: Ideal Model-Based PT-SMC...\n');
    res0 = exp0_ideal_mb(t_final);
    
    fprintf('Running Experiment 1: Disturbed Model-Based PT-SMC...\n');
    res1 = exp1_disturbed_mb(t_final);
    
    fprintf('Running Experiment 2: Saturation without Anti-Windup...\n');
    res2 = exp2_sat_no_antiwindup(t_final);
    
    fprintf('Running Experiment 3: Saturation with Anti-Windup...\n');
    res3 = exp3_sat_antiwindup(t_final);
    
    fprintf('Running Experiment 4: Proposed RL Predefined-Time SMC...\n');
    res4 = exp4_rl_pts_mc(t_final);
    
    fprintf('Running Experiment 5: Conventional SMC Baseline...\n');
    res5 = exp5_comparison_smc(t_final);
    
    output_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'results');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    mat_path = fullfile(output_dir, 'experiment_results.mat');
    save(mat_path, 'res0', 'res1', 'res2', 'res3', 'res4', 'res5', '-v7.3');
    fprintf('Saved all experiment results to %s!\n', mat_path);
end
