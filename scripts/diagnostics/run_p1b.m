clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'p1b_console.txt'));

diagnose_stepP1b_epsilon_sensitivity(1.0, 1e-4);

diary off;
exit;
