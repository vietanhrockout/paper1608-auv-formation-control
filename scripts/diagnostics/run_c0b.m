clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'c0b_console.txt'));
diagnose_stepC0b_checkpoint_resume_equivalence(0.6, 1e-4);
diary off;
exit;
