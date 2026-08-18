clear all; clear functions;
repo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(repo_root, 'paper1608')));
paths = project_paths();
diary(fullfile(paths.diagnostics, 'k5_throughput2_console.txt'));
diagnose_stepK5_hotphase_throughput(0.002, 1e-6);
diary off;
exit;
