clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'p2_console.txt'));

diagnose_stepP2_micro_horizon_ab_test(2.0, 1e-4);

diary off;
exit;
