function verify_step51_exp_runner()
    % VERIFY_STEP51_EXP_RUNNER Tests unified experiment runner function
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    run_all_experiments(0.1);
    
    mat_path = fullfile(project_root, 'results', 'experiment_results.mat');
    if ~exist(mat_path, 'file')
        error('STEP 51: FAIL - MAT file experiment_results.mat was not created');
    end
    
    fprintf('STEP 51: PASS\n');
end
