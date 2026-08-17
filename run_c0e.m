clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0e_console.txt');
diagnose_stepC0e_git_binding_integrity(0.6, 1e-4);
diary off;
exit;
