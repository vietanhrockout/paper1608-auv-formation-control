clear all; clear functions;
addpath(genpath('paper1608'));
diary('k5_cold_short_console.txt');
diagnose_stepK5_coldphase_instrumented(0.1);
diary off;
exit;
