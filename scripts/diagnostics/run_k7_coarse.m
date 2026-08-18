clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k7_coarse_console.txt'));
diagnose_stepK7_coarse_projected_rk4(1.0, 1e-4);
diary off;
exit;
