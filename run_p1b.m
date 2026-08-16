clear all; clear functions;
addpath(genpath('paper1608'));
diary('p1b_console.txt');

diagnose_stepP1b_epsilon_sensitivity(1.0, 1e-4);

diary off;
exit;
