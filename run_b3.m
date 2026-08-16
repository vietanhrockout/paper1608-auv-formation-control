clear all; clear functions;
addpath(genpath('paper1608'));
diary('phase_b3_console.txt');

verify_phase_b3_projected_convergence(15.0, 1e-4);

diary off;
exit;
