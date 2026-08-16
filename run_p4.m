clear all; clear functions;
addpath(genpath('paper1608'));
diary('p4_console.txt');

diagnose_stepP4_h_convergence_under_fix(0.3, 1e-4, 1e-5);

diary off;
exit;
