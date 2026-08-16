clear all; clear functions;
addpath(genpath('paper1608'));
diary('c0c_console.txt');
diagnose_stepC0c_multi_resume_equivalence(0.9, 1e-4);
diary off;
exit;
