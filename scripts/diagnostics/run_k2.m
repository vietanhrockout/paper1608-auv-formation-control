repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k2_console.txt'));
diagnose_stepK2_micro_projection_crossing();
diary off;
exit;
