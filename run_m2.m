clear all; clear functions;
addpath(genpath('paper1608'));
diary('m2_console.txt');
diagnose_stepM2_micro_horizon_fix_verification();
diary off;
exit;
