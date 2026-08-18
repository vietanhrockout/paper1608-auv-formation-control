clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'p4_console.txt'));

diagnose_stepP4_h_convergence_under_fix(0.3, 1e-4, 1e-5);

diary off;
exit;
