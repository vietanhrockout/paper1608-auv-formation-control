try
    addpath(genpath('paper1608'));
    params = simulation_params();
    [eta_init, ~] = initial_conditions();
    offsets = formation_offsets();

    chi_B = eta_init(:,3) - eta_init(:,1) - offsets(:,3);
    eta = eta_init(:,3);

    j = 1;
    delta = 1e-12;
    alpha1 = params.alpha1;
    eps_v = 1e-6;

    vel = zeros(6,1);
    vel(j) = delta;

    L = gain_matrix_L(chi_B, params);
    Lt = gain_matrix_Ltilde(chi_B, params);

    s = sliding_surface(chi_B, vel, params);

    term_surface = -(1/alpha1) * (Lt+L) * sigpow(vel,2-alpha1);
    term_robust = -params.k0*sign(s);

    q = pt_reaching_term(s,params);

    sig_v_neg = sigpow_negative(vel, 1-alpha1, 'literal', eps_v);

    F = q + params.k1*s;

    term_reaching = -(1/alpha1) * sig_v_neg .* F;

    J = jacobian_J(eta);
    M = mass_matrix();

    tau_reaching = (J') * ((J') \ (M * (J \ term_reaching)));

    fid = fopen('test_out.txt', 'w');
    fprintf(fid, 'sig_v_neg(1) = %.12e\n', sig_v_neg(1));
    fprintf(fid, 'tau_reaching(1) = %.12e\n', tau_reaching(1));
    fprintf(fid, 'any NaN in term_reaching? %d\n', any(isnan(term_reaching)));
    fprintf(fid, 'any NaN in tau_reaching? %d\n', any(isnan(tau_reaching)));
    fclose(fid);
catch ME
    fid = fopen('err.txt', 'w');
    fprintf(fid, 'Error: %s\n', ME.message);
    for k = 1:numel(ME.stack)
        fprintf(fid, '  in %s at line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    fclose(fid);
end
exit;
