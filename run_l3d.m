clear all; clear functions;
addpath(genpath('paper1608'));
diary('l3d_console.txt');
diagnose_stepL3d_near_zero_velocity_singularity();
diary off;
exit;
