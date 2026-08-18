function verify_step02_notation()
    % VERIFY_STEP02_NOTATION Verifies equations_used.md documentation
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    doc_path = fullfile(project_root, 'docs', 'equations_used.md');
    
    if exist(doc_path, 'file') ~= 2
        error('STEP 02: FAIL - docs/equations_used.md file missing');
    end
    
    % NOTE: fopen's 3rd positional argument is MACHINEFORMAT, not the
    % literal string 'encoding' -- the previous form
    % fopen(path,'r','encoding','UTF-8') raised "Invalid machine format"
    % on every call, so this check never actually ran. 'n' = native.
    fid = fopen(doc_path, 'r', 'n', 'UTF-8');
    content = fread(fid, '*char')';
    fclose(fid);
    
    % Check for key notation entries
    required_keys = {'eta', 'nu', 'chi', 'vel_err', 's', 'omega_aw', ...
                     'tau_cmd', 'tau_act', 'delta_tau', 'f_true', 'f_rl', 'C_hat'};
                 
    for i = 1:length(required_keys)
        if ~contains(content, required_keys{i})
            error('STEP 02: FAIL - Missing key notation in equations_used.md: %s', required_keys{i});
        end
    end
    
    fprintf('STEP 02: PASS\n');
end
