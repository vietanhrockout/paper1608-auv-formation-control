clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.validation, 'phase_b3_console.txt'));

verify_phase_b3_projected_convergence(15.0, 1e-4);

diary off;
exit;
