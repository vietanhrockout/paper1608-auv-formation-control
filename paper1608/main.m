% MAIN.M - Main Entry Point for Paper 1608 Simulation Reproduce Suite
% Executes complete reproduction workflow, runs all unit tests, executes simulations, and renders Figures 2-9.
%
% Phase C.0 gate follow-up (P1 finding, second GPT audit pass): this
% script used to call generate_all_paper_figures() with no argument,
% which now hard-errors (that function's figure numbering does not match
% the real paper -- see paper1608/docs/EQUATION_MAPPING.md). Silently
% running Steps 1-2 (now ~tens of minutes, see warning below, since Step
% 2 uses the corrected-but-much-slower Projected RK4 integrator) only to
% crash uncaught at Step 3 was a real regression. Fixed: an upfront
% warning (not a hard abort -- Steps 1-2 are still legitimate and worth
% running) plus a graceful, non-crashing status message at Step 3 instead
% of letting the guard's error propagate uncaught.

clear; clc; close all;

project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));

fprintf('===================================================================\n');
fprintf('  PAPER 1608 MATLAB SIMULATION REPRODUCTION SUITE\n');
fprintf('  "RL Predefined-Time Formation Control for Uncertain AUVs"\n');
fprintf('===================================================================\n\n');
fprintf('NOTE: Step 2 now uses the production Projected-RK4 integrator for\n');
fprintf('Experiment 4 (paper1608/simulation/exp4_rl_pts_mc_projected.m) instead\n');
fprintf('of the old broken ode45 path -- at h=1e-4 this makes Step 2 take on\n');
fprintf('the order of tens of minutes for a 20s horizon, not seconds.\n');
fprintf('NOTE: Step 3''s figure-generation pipeline is currently STALE (figure\n');
fprintf('numbering does not match the real paper -- see EQUATION_MAPPING.md)\n');
fprintf('and is skipped with a status message below rather than run.\n\n');

% 1. Execute full verification suite
fprintf('--- Step 1: Running Master Verification Suite ---\n');
run_all_verifications;

% 2. Execute full 20s experiment simulations
fprintf('\n--- Step 2: Running Closed-Loop Experiments 0 to 5 (20s) ---\n');
run_all_experiments(20.0);

% 3. Generate and save paper figures 2-9 -- guarded, see comment above.
fprintf('\n--- Step 3: Generating and Saving Paper Figures 2 to 9 ---\n');
try
    generate_all_paper_figures();
catch ME
    fprintf('SKIPPED: %s\n', ME.message);
    fprintf('Figure generation was NOT run (deliberately -- see EQUATION_MAPPING.md and\n');
    fprintf('IMPLEMENTATION_STATUS.md for the correct Fig.1-9 mapping and current status).\n');
    fprintf('Results from Steps 1-2 above are still valid and saved in results/.\n');
end

fprintf('\n===================================================================\n');
fprintf('  REPRODUCTION WORKFLOW FINISHED (see notes above for Step 3 status).\n');
fprintf('  Deliverables from Steps 1-2 saved in results/. Step 3 output, if any,\n');
fprintf('  saved in plots/ -- check the log above to see whether it actually ran.\n');
fprintf('===================================================================\n');
