function verify_step03_audit()
    % VERIFY_STEP03_AUDIT Verifies docs/assumptions_log.md audit log and paper_params.m config flags
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    
    doc_path = fullfile(project_root, 'docs', 'assumptions_log.md');
    if exist(doc_path, 'file') ~= 2
        error('STEP 03: FAIL - docs/assumptions_log.md file missing');
    end
    
    % NOTE: fopen's 3rd positional argument is MACHINEFORMAT, not the
    % literal string 'encoding' -- the previous form
    % fopen(path,'r','encoding','UTF-8') raised "Invalid machine format"
    % on every call, so this check never actually ran. 'n' = native.
    fid = fopen(doc_path, 'r', 'n', 'UTF-8');
    content = fread(fid, '*char')';
    fclose(fid);
    
    % Check for mandatory issue IDs
    required_issues = {
        'ISSUE_A_SLIDING_SURFACE'
        'ISSUE_B_GAIN_FORMULAS'
        'ISSUE_C_NEGATIVE_SIGMA'
        'ISSUE_D_REF_ACCEL_SIGN'
        'ISSUE_E_SATURATION_DEVIATION'
        'ISSUE_F_CRITIC_INPUT'
        'ISSUE_G_ACTOR_DIM_CONSISTENCY'
    };
    
    for i = 1:length(required_issues)
        if ~contains(content, required_issues{i})
            error('STEP 03: FAIL - Missing issue ID in assumptions_log.md: %s', required_issues{i});
        end
    end
    
    % Verify paper_params struct defines all mandatory audit config flags
    params = paper_params();
    required_flags = {'sigma_mode', 'ref_accel_sign', 'gain_formula_power', 'critic_input_mode'};
    for k = 1:length(required_flags)
        if ~isfield(params, required_flags{k})
            error('STEP 03: FAIL - Missing config flag in paper_params.m: %s', required_flags{k});
        end
    end
    
    fprintf('STEP 03: PASS\n');
end
