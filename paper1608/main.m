% MAIN.M - Main Entry Point for Paper 1608 Simulation Reproduce Suite
% Executes complete reproduction workflow, runs all unit tests, executes simulations, and renders Figures 2-9.

clear; clc; close all;

project_root = fileparts(mfilename('fullpath'));
addpath(genpath(project_root));

fprintf('===================================================================\n');
fprintf('  PAPER 1608 MATLAB SIMULATION REPRODUCTION SUITE\n');
fprintf('  "RL Predefined-Time Formation Control for Uncertain AUVs"\n');
fprintf('===================================================================\n\n');

% 1. Execute full verification suite
fprintf('--- Step 1: Running Master Verification Suite ---\n');
run_all_verifications;

% 2. Execute full 20s experiment simulations
fprintf('\n--- Step 2: Running Closed-Loop Experiments 0 to 5 (20s) ---\n');
run_all_experiments(20.0);

% 3. Generate and save paper figures 2-9
fprintf('\n--- Step 3: Generating and Saving Paper Figures 2 to 9 ---\n');
generate_all_paper_figures();

fprintf('\n===================================================================\n');
fprintf('  REPRODUCTION COMPLETE! All deliverables saved in results/ & plots/\n');
fprintf('===================================================================\n');
