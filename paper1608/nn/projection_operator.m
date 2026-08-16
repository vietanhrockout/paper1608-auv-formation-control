function wdot = projection_operator(w, v, delta)
    % PROJECTION_OPERATOR Bounded parameter projection operator (Paper Eq. 20 & Eq. 38)
    % Accepts desired unprojected derivative v (e.g., v = -\lambda_c c_e \Phi)
    % Ensures w' * wdot = 0 at boundary to keep norm(w) <= delta.
    
    tol = 1e-10;
    nw = norm(w);
    
    if nw < delta - tol
        % Interior: exact desired derivative (gradient descent)
        wdot = v;
        return;
    end
    
    radial = w' * v;
    if radial <= 0
        % Inward or tangential update
        wdot = v;
    else
        % Remove outward radial component (Paper Eq. 20 & Eq. 38)
        wdot = v - (radial / (w' * w)) * w;
    end
end
