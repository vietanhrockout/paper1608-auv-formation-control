clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0a_console.txt');
diagnose_stepC0a_decimation_equivalence(0.5, 1e-4, 7);
diary off;
exit;
