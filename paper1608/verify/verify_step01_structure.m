function verify_step01_structure()
    % VERIFY_STEP01_STRUCTURE Checks directory structure existence for Paper 1608
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    
    required_dirs = {
        'config'
        'model'
        'reference'
        'math'
        'control'
        'nn'
        'simulation'
        'verify'
        'plots'
        'results'
        'docs'
    };
    
    for i = 1:length(required_dirs)
        dir_path = fullfile(project_root, required_dirs{i});
        if exist(dir_path, 'dir') ~= 7
            error('STEP 01: FAIL - Required directory missing: %s', required_dirs{i});
        end
    end
    
    % Check main entry point
    if exist(fullfile(project_root, 'main.m'), 'file') ~= 2
        error('STEP 01: FAIL - main.m file missing');
    end
    
    fprintf('STEP 01: PASS\n');
end
