clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l3d_console.txt'));
diagnose_stepL3d_near_zero_velocity_singularity();
diary off;
exit;
