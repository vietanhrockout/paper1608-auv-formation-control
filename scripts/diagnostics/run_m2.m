clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'm2_console.txt'));
diagnose_stepM2_micro_horizon_fix_verification();
diary off;
exit;
