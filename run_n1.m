clear all; clear functions;
addpath(genpath('paper1608'));
diary('n1_console.txt');
diagnose_stepN1_projection_bound_scale();
diary off;
exit;
