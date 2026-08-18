clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
if ~exist(paths.phase_c_work, 'dir')
    mkdir(paths.phase_c_work);
end
diary(fullfile(paths.phase_c_work, 'phase_c_analysis_console.txt'));
analyze_phase_c_result();
diary off;
exit;
