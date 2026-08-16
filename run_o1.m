clear all; clear functions;
addpath(genpath('paper1608'));
diary('o1_console.txt');

diagnose_stepO1_leader_nonconvergence();

diary off;
exit;
