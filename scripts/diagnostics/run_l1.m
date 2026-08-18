repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l1_console.txt'));
diagnose_stepL1_initial_command_decomposition();
diary off;
exit;
