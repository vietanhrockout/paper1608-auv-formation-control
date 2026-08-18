clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l3e_console.txt'));
diagnose_stepL3e_auv0_q_origin();
diary off;
exit;
