% RUN_PHASE_C Launch the full Phase C (100s) production simulation.
%
% Unlike this project's other run_*.m launchers, this one deliberately
% does NOT diary() to a tracked repo-root filename -- GPT's round-6
% review found that a tracked diary file dirties the git tree via its
% own write, before git_fingerprint() is even sampled, which would
% defeat the whole point of checking for a clean launch. Console output
% goes to phase_c_results/phase_c_console.txt instead (gitignored, see
% .gitignore), keeping the tree clean throughout the run.
%
% Usage: run this file directly (e.g. `matlab -batch "run('run_phase_c.m')"`).
% Expected wall time: ~2.4 hours at the default h=1e-4/t_final=100.
% Refuses to launch from a dirty git tree by default -- commit your
% changes first. Do NOT edit/commit this repo while the run is in progress
% (see projected_rk4_integrate.m's mid-run drift-abort check).

clear all; clear functions;
addpath(genpath('paper1608'));

results_dir = fullfile(fileparts(mfilename('fullpath')), 'phase_c_results');
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
diary(fullfile(results_dir, 'phase_c_console.txt'));

run_phase_c_production(100.0, 1e-4, 1001, false);

diary off;
exit;
