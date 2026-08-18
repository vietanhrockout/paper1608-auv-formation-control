clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k6_ode15s_console.txt'));
diagnose_stepK6_stiff_solver_test('ode15s', 2.0);
diary off;
exit;
