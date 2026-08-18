clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'c0d_console.txt'));
diagnose_stepC0d_cwd_independent_fingerprint();
diary off;
exit;
