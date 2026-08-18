repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l3a_console.txt'));
diagnose_stepL3a_follower_error_architecture();
diary off;
exit;
