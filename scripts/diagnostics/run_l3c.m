repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l3c_console.txt'));
diagnose_stepL3c_initial_command_leader_relative();
diary off;
exit;
