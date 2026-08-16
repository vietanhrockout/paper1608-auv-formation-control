clear all; clear functions;
addpath(genpath('paper1608'));
diary('p2_5s_console.txt');

diagnose_stepP2_micro_horizon_ab_test(5.0, 1e-4);

diary off;
exit;
