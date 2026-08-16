function diagnose_stepK1_initial_critic_scale()
    % DIAGNOSE_STEPK1_INITIAL_CRITIC_SCALE
    % Pure diagnostic:
    %   PT-SMC command scale -> Critic cost -> Critic gradient scale
    % No tuning, no clipping, no model modification.

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    params  = simulation_params();
    cfg     = nn_config();
    sat_cfg = saturation_config();

    t0 = 0.0;

    [eta_init, nu_init] = initial_conditions();

    out_file = fullfile(fileparts(project_root), 'k1_results.txt');
    fid = fopen(out_file, 'w');

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf(' STEP K.1 -- INITIAL CRITIC SCALE / CAUSALITY DIAGNOSTIC\n');
    fprintf('============================================================\n');

    fprintf('sigma mode = %s\n', params.sigma_mode);
    fprintf('delta_c    = %.6e\n', cfg.delta_c);
    fprintf('lambda_c   = %.6e\n', params.lambda_c);

    if fid > 0
        fprintf(fid, '============================================================\n');
        fprintf(fid, ' STEP K.1 -- INITIAL CRITIC SCALE / CAUSALITY DIAGNOSTIC\n');
        fprintf(fid, '============================================================\n');
        fprintf(fid, 'sigma mode = %s\n', params.sigma_mode);
        fprintf(fid, 'delta_c    = %.6e\n', cfg.delta_c);
        fprintf(fid, 'lambda_c   = %.6e\n', params.lambda_c);
    end

    for i = 1:3

        eta = eta_init(:, i);
        nu  = nu_init(:, i);

        J = jacobian_J(eta);
        eta_dot = J * nu;

        omega_aw = zeros(6,1);
        Wa = zeros(cfg.actor_n_nodes, 6);
        Wc = zeros(cfg.critic_n_nodes, 1);

        [chi, vel_err] = formation_error( ...
            eta, eta_dot, t0, i);

        s = sliding_surface( ...
            chi, vel_err, params);

        [tau_cmd, terms] = controller_rl( ...
            eta, eta_dot, t0, i, ...
            omega_aw, Wa, params, cfg);

        [tau_act, delta_tau] = sat_vector( ...
            tau_cmd, ...
            sat_cfg.tau_min, ...
            sat_cfg.tau_max);

        r = strategic_utility(chi, tau_cmd);

        [ce, Phi] = bellman_error( ...
            chi, vel_err, Wc, ...
            tau_cmd, params, cfg);

        desired_update = ...
            -params.lambda_c * ce * Phi;

        projected_update = projection_operator( ...
            Wc, desired_update, cfg.delta_c);

        C_hat = critic_output(chi, Wc, cfg);

        grad_norm = norm(desired_update);

        if grad_norm > 0
            t_boundary_linear = ...
                cfg.delta_c / grad_norm;
        else
            t_boundary_linear = Inf;
        end

        fprintf('\n------------------------------------------------------------\n');
        fprintf('AUV %d\n', i-1);
        fprintf('------------------------------------------------------------\n');

        fprintf('||chi(0)||_inf        = %.6e\n', norm(chi, inf));
        fprintf('||vel_err(0)||_inf    = %.6e\n', norm(vel_err, inf));
        fprintf('||s(0)||_inf          = %.6e\n', norm(s, inf));
        fprintf('||Wc(0)||             = %.6e\n', norm(Wc));
        fprintf('||Wa(0)||_F           = %.6e\n', norm(Wa, 'fro'));
        fprintf('C_hat(0)               = %.6e\n', C_hat);
        fprintf('||term_surface||_inf  = %.6e\n', norm(terms.term_surface, inf));
        fprintf('||term_reaching||_inf = %.6e\n', norm(terms.term_reaching, inf));
        fprintf('||term_RL||_inf       = %.6e\n', norm(terms.term_rl, inf));
        fprintf('max |tau_cmd force|   = %.6e N\n', max(abs(tau_cmd(1:3))));
        fprintf('max |tau_act force|   = %.6e N\n', max(abs(tau_act(1:3))));
        fprintf('max |delta_tau|       = %.6e\n', max(abs(delta_tau)));
        fprintf('r(0)                   = %.6e\n', r);
        fprintf('c_e(0)                 = %.6e\n', ce);
        fprintf('||Phi(0)||             = %.6e\n', norm(Phi));
        fprintf('||v_c(0)||             = %.6e weight/s\n', grad_norm);
        fprintf('delta_c / ||v_c(0)||   = %.6e s\n', t_boundary_linear);
        fprintf('projection interior err= %.6e\n', norm(projected_update - desired_update));

        if fid > 0
            fprintf(fid, '\n------------------------------------------------------------\n');
            fprintf(fid, 'AUV %d\n', i-1);
            fprintf(fid, '------------------------------------------------------------\n');
            fprintf(fid, '||chi(0)||_inf        = %.6e\n', norm(chi, inf));
            fprintf(fid, '||vel_err(0)||_inf    = %.6e\n', norm(vel_err, inf));
            fprintf(fid, '||s(0)||_inf          = %.6e\n', norm(s, inf));
            fprintf(fid, '||Wc(0)||             = %.6e\n', norm(Wc));
            fprintf(fid, '||Wa(0)||_F           = %.6e\n', norm(Wa, 'fro'));
            fprintf(fid, 'C_hat(0)               = %.6e\n', C_hat);
            fprintf(fid, '||term_surface||_inf  = %.6e\n', norm(terms.term_surface, inf));
            fprintf(fid, '||term_reaching||_inf = %.6e\n', norm(terms.term_reaching, inf));
            fprintf(fid, '||term_RL||_inf       = %.6e\n', norm(terms.term_rl, inf));
            fprintf(fid, 'max |tau_cmd force|   = %.6e N\n', max(abs(tau_cmd(1:3))));
            fprintf(fid, 'max |tau_act force|   = %.6e N\n', max(abs(tau_act(1:3))));
            fprintf(fid, 'max |delta_tau|       = %.6e\n', max(abs(delta_tau)));
            fprintf(fid, 'r(0)                   = %.6e\n', r);
            fprintf(fid, 'c_e(0)                 = %.6e\n', ce);
            fprintf(fid, '||Phi(0)||             = %.6e\n', norm(Phi));
            fprintf(fid, '||v_c(0)||             = %.6e weight/s\n', grad_norm);
            fprintf(fid, 'delta_c / ||v_c(0)||   = %.6e s\n', t_boundary_linear);
            fprintf(fid, 'projection interior err= %.6e\n', norm(projected_update - desired_update));
        end

        % Causality oracle:
        % At t=0 both neural networks are zero.
        assert(norm(Wc) < 1e-14);
        assert(norm(Wa, 'fro') < 1e-14);

        % Actor contributes zero model compensation initially.
        assert(norm(terms.term_rl, inf) < 1e-12);

        % Projection must be inactive at Wc = 0.
        tol_proj = 1e-10 * max(1, norm(desired_update));

        assert( ...
            norm(projected_update - desired_update) < tol_proj, ...
            'K.1 FAIL: projection modified an interior update.');
    end

    fprintf('\n============================================================\n');
    fprintf(' STEP K.1 DIAGNOSTIC COMPLETED\n');
    fprintf(' No parameter or controller modification was performed.\n');
    fprintf('============================================================\n');

    if fid > 0
        fprintf(fid, '\n============================================================\n');
        fprintf(fid, ' STEP K.1 DIAGNOSTIC COMPLETED\n');
        fprintf(fid, '============================================================\n');
        fclose(fid);
    end
end
