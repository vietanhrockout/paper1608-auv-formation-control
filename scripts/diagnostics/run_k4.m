repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k4_console.txt'));
diagnose_stepK4_projected_rk4_feasibility();
diary off;
exit;
