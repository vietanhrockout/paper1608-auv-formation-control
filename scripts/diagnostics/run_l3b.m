repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l3b_console.txt'));
diagnose_stepL3b_fig9_sliding_visibility();
diary off;
exit;
