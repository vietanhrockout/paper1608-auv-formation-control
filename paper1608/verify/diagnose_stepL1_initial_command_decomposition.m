function diagnose_stepL1_initial_command_decomposition()
% DIAGNOSE_STEPL1_INITIAL_COMMAND_DECOMPOSITION
%
% Issue L / Step L.1
%
% Pure diagnostic decomposition of the initial Eq. (31) control command.
%
% NO tuning.
% NO solver modification.
% NO clipping.
% NO projection modification.
% NO parameter change.
%
% Three sigma branches are evaluated only for sensitivity/audit:
%   paper_literal
%   sign_flip_candidate
%   eq29_consistent

    project_root = fileparts(fileparts(mfilename('fullpath')));

    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'model'));
    addpath(fullfile(project_root, 'reference'));
    addpath(fullfile(project_root, 'math'));
    addpath(fullfile(project_root, 'control'));
    addpath(fullfile(project_root, 'nn'));
    addpath(fullfile(project_root, 'simulation'));

    cfg     = nn_config();
    sat_cfg = saturation_config();

    [eta_init, nu_init] = initial_conditions();

    t0 = 0.0;

    omega0 = zeros(6,1);
    Wa0    = zeros(cfg.actor_n_nodes,6);
    Wc0    = zeros(cfg.critic_n_nodes,1);

    modes = { ...
        'paper_literal', ...
        'sign_flip_candidate', ...
        'eq29_consistent'};

    out_file = fullfile(fileparts(project_root), 'l1_results.txt');
    fid = fopen(out_file, 'w');

    function p(fmt, varargin)
        fprintf(fmt, varargin{:});
        if fid > 0
            fprintf(fid, fmt, varargin{:});
        end
    end

    p('\n');
    p('============================================================\n');
    p(' ISSUE L / STEP L.1 -- INITIAL COMMAND DECOMPOSITION\n');
    p('============================================================\n');

    for m = 1:numel(modes)

        params = simulation_params();

        params.sigma_mode = modes{m};
        params = derived_params(params);

        p('\n');
        p('============================================================\n');
        p('SIGMA MODE: %s\n', modes{m});
        p('sigma1 = %.12e\n', params.sigma1);
        p('sigma2 = %.12e\n', params.sigma2);
        p('============================================================\n');

        for i = 1:3

            eta = eta_init(:,i);
            nu  = nu_init(:,i);

            J = jacobian_J(eta);
            eta_dot = J * nu;

            [chi, vel_err] = formation_error( ...
                eta, eta_dot, t0, i);

            L      = gain_matrix_L(chi, params);
            Ltilde = gain_matrix_Ltilde(chi, params);

            s = sliding_surface(chi, vel_err, params);

            alpha1 = params.alpha1;

            sig_v_2minus = sigpow(vel_err, 2 - alpha1);

            term_surface = -(1/alpha1) * (Ltilde + L) * sig_v_2minus;

            term_robust = -params.k0 * sign(s);

            sig_v_neg = sigpow_negative(vel_err, 1 - alpha1, 'regularized', 1e-6);

            gv = (1/alpha1) * sig_v_neg;

            q1 = params.sigma1 * sigpow(s, params.zeta2);

            q2 = params.sigma2 * sigpow(s, params.zeta3);

            q_inner = q1 + q2;

            q = sigpow(q_inner, params.zeta1);

            term_q = -gv .* q;

            term_k1 = -gv .* (params.k1 * s);

            term_aw = -gv .* omega0;

            term_reaching = term_q + term_k1 + term_aw;

            [~, ~, eta_ddot_ref] = reference_1608(t0);

            term_reference = params.ref_accel_sign * eta_ddot_ref;

            f_rl = actor_output(chi, vel_err, Wa0, cfg);

            term_rl = -f_rl;

            tau_surface = virtual_to_tau(eta, term_surface);
            tau_robust  = virtual_to_tau(eta, term_robust);
            tau_q       = virtual_to_tau(eta, term_q);
            tau_k1      = virtual_to_tau(eta, term_k1);
            tau_aw      = virtual_to_tau(eta, term_aw);
            tau_ref     = virtual_to_tau(eta, term_reference);
            tau_rl      = virtual_to_tau(eta, term_rl);

            tau_reconstructed = ...
                  tau_surface ...
                + tau_robust ...
                + tau_q ...
                + tau_k1 ...
                + tau_aw ...
                + tau_ref ...
                + tau_rl;

            [tau_cmd, terms] = controller_rl( ...
                eta, eta_dot, t0, i, omega0, Wa0, params, cfg);

            recon_err = norm(tau_reconstructed - tau_cmd, inf);

            recon_scale = max(1, norm(tau_cmd, inf));

            assert(recon_err < 1e-10 * recon_scale, ...
                'L.1 FAIL: Eq.31 decomposition does not reconstruct controller.');

            reaching_err = norm(term_reaching - terms.term_reaching, inf);

            reaching_scale = max(1, norm(terms.term_reaching, inf));

            assert(reaching_err < 1e-10 * reaching_scale, ...
                'L.1 FAIL: reaching subterm decomposition mismatch.');

            [tau_act, delta_tau] = sat_vector( ...
                tau_cmd, sat_cfg.tau_min, sat_cfg.tau_max);

            r_cmd = strategic_utility(chi, tau_cmd);

            r_act = strategic_utility(chi, tau_act);

            [ce, Phi] = bellman_error( ...
                chi, vel_err, Wc0, tau_cmd, params, cfg);

            vc_raw = -params.lambda_c * ce * Phi;

            if norm(vc_raw) > 0
                Tdelta = cfg.delta_c / norm(vc_raw);
            else
                Tdelta = Inf;
            end

            [~, jforce] = max(abs(tau_cmd(1:3)));

            p('\n------------------------------------------------------------\n');
            p('AUV %d\n', i-1);
            p('------------------------------------------------------------\n');

            p('||chi||_inf       = %.12e\n', norm(chi,inf));
            p('||vel_err||_inf   = %.12e\n', norm(vel_err,inf));
            p('||s||_inf         = %.12e\n', norm(s,inf));

            p('\nREACHING INTERNALS\n');
            p('||sig_v_neg||_inf = %.12e\n', norm(sig_v_neg,inf));
            p('||q1||_inf        = %.12e\n', norm(q1,inf));
            p('||q2||_inf        = %.12e\n', norm(q2,inf));
            p('||q_inner||_inf   = %.12e\n', norm(q_inner,inf));
            p('||q(s)||_inf      = %.12e\n', norm(q,inf));
            p('||k1*s||_inf      = %.12e\n', norm(params.k1*s,inf));

            p('\nVIRTUAL-ACCELERATION TERMS\n');
            p('||surface||_inf   = %.12e\n', norm(term_surface,inf));
            p('||robust||_inf    = %.12e\n', norm(term_robust,inf));
            p('||q-term||_inf    = %.12e\n', norm(term_q,inf));
            p('||k1s-term||_inf  = %.12e\n', norm(term_k1,inf));
            p('||AW-term||_inf   = %.12e\n', norm(term_aw,inf));
            p('||reference||_inf = %.12e\n', norm(term_reference,inf));
            p('||RL-term||_inf   = %.12e\n', norm(term_rl,inf));

            p('\nFORCE CONTRIBUTIONS\n');
            p('max |tau_surface force| = %.12e N\n', max(abs(tau_surface(1:3))));
            p('max |tau_robust force|  = %.12e N\n', max(abs(tau_robust(1:3))));
            p('max |tau_q force|       = %.12e N\n', max(abs(tau_q(1:3))));
            p('max |tau_k1 force|      = %.12e N\n', max(abs(tau_k1(1:3))));
            p('max |tau_AW force|      = %.12e N\n', max(abs(tau_aw(1:3))));
            p('max |tau_ref force|     = %.12e N\n', max(abs(tau_ref(1:3))));
            p('max |tau_RL force|      = %.12e N\n', max(abs(tau_rl(1:3))));

            p('\nTOTAL COMMAND\n');
            p('dominant force DOF      = %d\n', jforce);
            p('tau_cmd xyz = [% .6e  % .6e  % .6e] N\n', tau_cmd(1), tau_cmd(2), tau_cmd(3));
            p('max |tau_cmd force|     = %.12e N\n', max(abs(tau_cmd(1:3))));
            p('max |tau_act force|     = %.12e N\n', max(abs(tau_act(1:3))));
            p('max |Delta tau|         = %.12e\n', max(abs(delta_tau)));
            p('force saturation ratio  = %.12e\n', max(abs(tau_cmd(1:3))) / 150);

            p('\nCOST / CRITIC CONSEQUENCE\n');
            p('r_cmd                    = %.12e\n', r_cmd);
            p('r_act diagnostic         = %.12e\n', r_act);
            p('r_cmd / r_act            = %.12e\n', r_cmd / max(r_act,eps));
            p('||Phi||                  = %.12e\n', norm(Phi));
            p('||v_c raw||              = %.12e weight/s\n', norm(vc_raw));
            p('delta_c/||v_c||          = %.12e s\n', Tdelta);

            p('\nRECONSTRUCTION\n');
            p('Eq31 reconstruction err  = %.12e\n', recon_err);
            p('reaching decomposition err= %.12e\n', reaching_err);
        end
    end

    p('\n');
    p('============================================================\n');
    p(' STEP L.1 COMPLETE\n');
    p(' No controller or parameter modification performed.\n');
    p('============================================================\n');

    if fid > 0
        fclose(fid);
    end
end

function tau = virtual_to_tau(eta, virtual_accel)
    J = jacobian_J(eta);
    M = mass_matrix();
    tau = (J') * ((J') \ (M * (J \ virtual_accel)));
end
