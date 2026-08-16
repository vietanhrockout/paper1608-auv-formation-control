function verify_step10_auv_params()
    % VERIFY_STEP10_AUV_PARAMS Verifies physical and hydrodynamic constants for AUV
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'model'));
    
    p = auv_parameters();
    
    if p.m <= 0 || p.g <= 0
        error('STEP 10: FAIL - Invalid mass or gravity');
    end
    if p.m11 <= 0 || p.m22 <= 0 || p.m33 <= 0 || p.m44 <= 0 || p.m55 <= 0 || p.m66 <= 0
        error('STEP 10: FAIL - Mass matrix diagonal elements must be positive');
    end
    
    % Check documentation existence
    doc_path = fullfile(project_root, 'docs', 'ref43_parameter_source.md');
    if exist(doc_path, 'file') ~= 2
        error('STEP 10: FAIL - Missing docs/ref43_parameter_source.md');
    end
    
    fprintf('STEP 10: PASS\n');
end
