clear all; clear functions;
addpath(genpath('paper1608'));
diary('k6_ode15s_console.txt');
diagnose_stepK6_stiff_solver_test('ode15s', 2.0);
diary off;
exit;
