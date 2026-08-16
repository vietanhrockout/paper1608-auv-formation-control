function fig = plot_fig2_3d_trajectory(res)
    % PLOT_FIG2_3D_TRAJECTORY Reproduces Figure 2: 3D Trajectory in Earth Frame
    
    fig = figure('Name', 'Figure 2: 3D Trajectory', 'Visible', 'off');
    hold on; grid on; box on;
    
    t = res.t;
    X = res.X;
    cfg = nn_config();
    
    % Extract trajectories
    pos_d0 = zeros(length(t), 3);
    pos_auv = zeros(length(t), 3, 3);
    
    for k = 1:length(t)
        [eta_d0, ~, ~] = reference_1608(t(k));
        pos_d0(k, :) = eta_d0(1:3)';
        [eta_mat, ~, ~, ~, ~] = unpack_states(X(k, :)', cfg);
        for i = 1:3
            pos_auv(k, :, i) = eta_mat(1:3, i)';
        end
    end
    
    plot3(pos_d0(:, 1), pos_d0(:, 2), pos_d0(:, 3), 'k--', 'LineWidth', 2, 'DisplayName', 'Virtual Leader');
    plot3(pos_auv(:, 1, 1), pos_auv(:, 2, 1), pos_auv(:, 3, 1), 'r-', 'LineWidth', 1.5, 'DisplayName', 'AUV 0');
    plot3(pos_auv(:, 1, 2), pos_auv(:, 2, 2), pos_auv(:, 3, 2), 'b-', 'LineWidth', 1.5, 'DisplayName', 'AUV 1');
    plot3(pos_auv(:, 1, 3), pos_auv(:, 2, 3), pos_auv(:, 3, 3), 'g-', 'LineWidth', 1.5, 'DisplayName', 'AUV 2');
    
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    title('Figure 2: 3D Trajectory of Leader and AUV Formation');
    legend('Location', 'best');
    view(3);
end
