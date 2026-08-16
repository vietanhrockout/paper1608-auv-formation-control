clear all; clear functions;
addpath(genpath('paper1608'));
diary('m1_console.txt');
diagnose_stepM1_critic_reward_saturation_coupling();
diary off;
exit;
