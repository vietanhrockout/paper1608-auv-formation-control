repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k1_diary_out.txt'));
diagnose_stepK1_initial_critic_scale();
diary off;
exit;
