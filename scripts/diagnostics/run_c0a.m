clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'c0a_console.txt'));
diagnose_stepC0a_decimation_equivalence(0.5, 1e-4, 7);
diary off;
exit;
