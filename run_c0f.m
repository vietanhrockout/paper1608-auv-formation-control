clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0f_console.txt');
diagnose_stepC0f_live_drift_rejection(0.6, 1e-4);
diary off;
exit;
