clear all; clear functions;
addpath(genpath('paper1608'));
diary('n1_100_console.txt');
diagnose_stepN1_single_delta(100, 2.0);
diary off;
exit;
