clear all; clear functions;
addpath(genpath('paper1608'));
diary('n1_1e8_console.txt');
diagnose_stepN1_single_delta(1e8, 2.0);
diary off;
exit;
