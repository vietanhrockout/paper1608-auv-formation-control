clear all; clear functions;
addpath(genpath('paper1608'));
diary('k7_coarse_console.txt');
diagnose_stepK7_coarse_projected_rk4(1.0, 1e-4);
diary off;
exit;
