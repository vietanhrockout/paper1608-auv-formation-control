function diagnose_stepL3a_follower_error_architecture()
% DIAGNOSE_STEPL3A_FOLLOWER_ERROR_ARCHITECTURE
%
% Reproduction-fidelity audit only.
%
% Compare:
%   A) current virtual-reference follower errors
%   B) actual-leader-relative follower errors
%
% NO ODE simulation.
% NO controller modification.
% NO formation_error.m modification.
% NO parameter tuning.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'control'));

    t0 = 0;

    [eta_init, nu_init] = initial_conditions();
    offsets = formation_offsets();

    [eta_d, eta_d_dot, ~] = reference_1608(t0);

    eta_dot = zeros(6,3);

    for i = 1:3
        J = jacobian_J(eta_init(:,i));
        eta_dot(:,i) = J * nu_init(:,i);
    end

    out_file = fullfile(fileparts(project_root), 'l3a_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    %% ============================================================
    % Candidate A: current virtual-reference architecture
    % =============================================================

    chi_virtual = zeros(6,3);
    vel_virtual = zeros(6,3);

    for i = 1:3
        chi_virtual(:,i) = ...
            eta_init(:,i) - eta_d - offsets(:,i);

        vel_virtual(:,i) = ...
            eta_dot(:,i) - eta_d_dot;
    end

    %% ============================================================
    % Candidate B: actual-leader-relative follower architecture
    % =============================================================

    chi_leader = zeros(6,3);
    vel_leader = zeros(6,3);

    % Leader tracks virtual desired trajectory
    chi_leader(:,1) = eta_init(:,1) - eta_d;
    vel_leader(:,1) = eta_dot(:,1) - eta_d_dot;

    % Followers track actual leader + formation offset
    for i = 2:3
        chi_leader(:,i) = ...
            eta_init(:,i) ...
            - eta_init(:,1) ...
            - offsets(:,i);

        vel_leader(:,i) = ...
            eta_dot(:,i) ...
            - eta_dot(:,1);
    end

    %% ============================================================
    % Initial relative distances
    % =============================================================

    dist_10 = eta_init(:,2) - eta_init(:,1);
    dist_20 = eta_init(:,3) - eta_init(:,1);

    p('\n');
    p('============================================================\n');
    p(' STEP L.3a -- FOLLOWER ERROR ARCHITECTURE AUDIT\n');
    p('============================================================\n');

    p('\nInitial desired leader position xyz:\n');
    p('  [%.12f  %.12f  %.12f]\n', eta_d(1:3).');

    p('Initial physical relative distance AUV1-AUV0 xyz:\n');
    p('  [%.12f  %.12f  %.12f]\n', dist_10(1:3).');

    p('Initial physical relative distance AUV2-AUV0 xyz:\n');
    p('  [%.12f  %.12f  %.12f]\n', dist_20(1:3).');

    p('\nDesired formation offsets xyz:\n');
    p('AUV1: [%.12f  %.12f  %.12f]\n', offsets(1:3,2).');
    p('AUV2: [%.12f  %.12f  %.12f]\n', offsets(1:3,3).');

    p('\n------------------------------------------------------------\n');
    p('CANDIDATE A: VIRTUAL REFERENCE\n');
    p('------------------------------------------------------------\n');

    for i = 1:3
        p('AUV%d chi_xyz = [%.12f  %.12f  %.12f]\n', i-1, chi_virtual(1:3,i).');
        p('AUV%d vel_err_xyz = [%.12f  %.12f  %.12f]\n', i-1, vel_virtual(1:3,i).');
    end

    p('\n------------------------------------------------------------\n');
    p('CANDIDATE B: ACTUAL LEADER RELATIVE\n');
    p('------------------------------------------------------------\n');

    for i = 1:3
        p('AUV%d chi_xyz = [%.12f  %.12f  %.12f]\n', i-1, chi_leader(1:3,i).');
        p('AUV%d vel_err_xyz = [%.12f  %.12f  %.12f]\n', i-1, vel_leader(1:3,i).');
    end

    %% ============================================================
    % Confirm what current formation_error.m actually implements
    % =============================================================

    p('\n------------------------------------------------------------\n');
    p('CURRENT CODE ORACLE\n');
    p('------------------------------------------------------------\n');

    for i = 1:3

        [chi_current, vel_current] = ...
            formation_error( ...
                eta_init(:,i), ...
                eta_dot(:,i), ...
                t0, i);

        err_chi = norm(chi_current - chi_virtual(:,i), inf);
        err_vel = norm(vel_current - vel_virtual(:,i), inf);

        p('AUV%d current-vs-virtual chi error = %.3e\n', i-1, err_chi);
        p('AUV%d current-vs-virtual vel error = %.3e\n', i-1, err_vel);

        assert(err_chi < 1e-12, 'L.3a FAIL: chi does not match Candidate A.');
        assert(err_vel < 1e-12, 'L.3a FAIL: vel does not match Candidate A.');
    end

    %% ============================================================
    % Exact initial-value oracles
    % =============================================================

    expected_virtual = [ ...
         6, -2, -6;
         6, -3,  1;
        16, 12,  8];

    expected_leader = [ ...
         6,  -8, -12;
         6,  -9,  -5;
        16,  -4,  -8];

    assert(norm(chi_virtual(1:3,:) - expected_virtual, inf) < 1e-12, ...
        'L.3a FAIL: virtual chi oracle mismatch.');

    assert(norm(chi_leader(1:3,:) - expected_leader, inf) < 1e-12, ...
        'L.3a FAIL: leader-relative chi oracle mismatch.');

    %% ============================================================
    % Quantify effect on literal Eq. (21) sliding scale
    % =============================================================

    params = paper_params();
    params = derived_params(params);

    s_virtual = zeros(6,3);
    s_leader  = zeros(6,3);

    for i = 1:3

        s_virtual(:,i) = ...
            sliding_surface( ...
                chi_virtual(:,i), ...
                vel_virtual(:,i), ...
                params);

        s_leader(:,i) = ...
            sliding_surface( ...
                chi_leader(:,i), ...
                vel_leader(:,i), ...
                params);
    end

    p('\n------------------------------------------------------------\n');
    p('LITERAL EQ. (21) INITIAL SLIDING SCALE\n');
    p('------------------------------------------------------------\n');

    for i = 1:3
        p('AUV%d ||s_virtual||_inf = %.12e, ||s_leader||_inf = %.12e\n', ...
            i-1, ...
            norm(s_virtual(:,i), inf), ...
            norm(s_leader(:,i), inf));
    end

    p('\nExpected current virtual values approximately:\n');
    p('AUV0: 3.492047e3\n');
    p('AUV1: 2.215353e3\n');
    p('AUV2: 1.167808e3\n');

    p('\nExpected leader-relative values approximately:\n');
    p('AUV0: 3.492047e3\n');
    p('AUV1: 1.406178e3\n');
    p('AUV2: 2.215208e3\n');

    p('\n============================================================\n');
    p(' STEP L.3a COMPLETE\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end
