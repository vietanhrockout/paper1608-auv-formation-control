clear all; clear functions;
addpath(genpath('paper1608'));
diary('k5_throughput2_console.txt');
diagnose_stepK5_hotphase_throughput(0.002, 1e-6);
diary off;
exit;
