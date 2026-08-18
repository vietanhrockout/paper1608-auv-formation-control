clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'm1_console.txt'));
diagnose_stepM1_critic_reward_saturation_coupling();
diary off;
exit;
