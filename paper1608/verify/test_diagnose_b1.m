function test_diagnose_b1(t_final)
    % TEST_DIAGNOSE_B1 Diagnostic tool for Phase B.1 simulation metrics
    if nargin < 1 || isempty(t_final)
        t_final = 5.0;
    end
    
    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));
    
    cfg = nn_config();
    sat_cfg = saturation_config();
    params = simulation_params();
    
    log_file = fullfile(pwd, 'diag_out.txt');
    fid = fopen(log_file, 'w');
    fprintf(fid, 'Starting %.1fs simulation with updated projection operator...\n', t_final);
    fclose(fid);
    
    res = exp4_rl_pts_mc(t_final);
    
    t_out = res.t;
    X_out = res.X;
    
    fid = fopen(log_file, 'a');
    fprintf(fid, 'Simulation finished. Steps = %d, Final t = %.2f\n', length(t_out), t_out(end));
    
    sample_times = [0.0, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0];
    if t_final > 5.0
        sample_times = [sample_times, 7.5, 10.0, 12.5, 15.0];
    end
    
    fprintf(fid, '\n--- Intermediate State & NN Weight Norm Diagnostics ---\n');
    fprintf(fid, '  t (s)    ||Wc1||    ||Wc2||    ||Wc3||    ||Wa1||_F   Max|tau_cmd| Force (N)   E_chi\n');
    fprintf(fid, '---------------------------------------------------------------------------------------\n');
    
    for st = sample_times
        [~, idx] = min(abs(t_out - st));
        if idx > length(t_out), continue; end
        X_k = X_out(idx, :)';
        t_k = t_out(idx);
        
        [eta_m, nu_m, omega_aw_mat, Wa_l, Wc_m] = unpack_states(X_k, cfg);
        
        norm_Wc = [norm(Wc_m(:,1)), norm(Wc_m(:,2)), norm(Wc_m(:,3))];
        norm_Wa1 = norm(Wa_l{1}, 'fro');
        
        max_tau = 0;
        e_chi_k = zeros(3, 1);
        for i = 1:3
            eta = eta_m(:, i);
            nu  = nu_m(:, i);
            J   = jacobian_J(eta);
            eta_dot = J * nu;
            [chi, ~] = formation_error(eta, eta_dot, t_k, i);
            e_chi_k(i) = max(abs(chi));
            
            tau_cmd = controller_rl(eta, eta_dot, t_k, i, omega_aw_mat(:, i), Wa_l{i}, params, cfg);
            max_tau = max(max_tau, max(abs(tau_cmd(1:3))));
        end
        
        fprintf(fid, '  %5.1f   %8.4f   %8.4f   %8.4f   %8.4f    %16.2f    %8.4f\n', ...
            t_k, norm_Wc(1), norm_Wc(2), norm_Wc(3), norm_Wa1, max_tau, max(e_chi_k));
    end
    fclose(fid);
end
