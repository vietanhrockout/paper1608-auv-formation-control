repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'l2_console.txt'));
diagnose_stepL2_sigma_theory_consistency();
diary off;
exit;
