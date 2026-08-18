clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'n1_100_console.txt'));
diagnose_stepN1_single_delta(100, 2.0);
diary off;
exit;
