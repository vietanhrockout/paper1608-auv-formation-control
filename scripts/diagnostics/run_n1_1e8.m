clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'n1_1e8_console.txt'));
diagnose_stepN1_single_delta(1e8, 2.0);
diary off;
exit;
