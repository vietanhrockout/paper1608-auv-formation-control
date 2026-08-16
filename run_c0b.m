clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0b_console.txt');
diagnose_stepC0b_checkpoint_resume_equivalence(0.6, 0.3, 1e-4);
diary off;
exit;
