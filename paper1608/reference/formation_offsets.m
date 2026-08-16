function offsets = formation_offsets()
    % FORMATION_OFFSETS Geometric formation configuration offsets for 3 AUVs
    % Leader (AUV0): [0, 0, 0, 0, 0, 0]^T
    % Follower 1 (AUV1): [3, 4, 2, 0, 0, 0]^T
    % Follower 2 (AUV2): [6, 1, 4, 0, 0, 0]^T
    
    offsets = zeros(6, 3);
    offsets(:, 1) = [0; 0; 0; 0; 0; 0];
    offsets(:, 2) = [3; 4; 2; 0; 0; 0];
    offsets(:, 3) = [6; 1; 4; 0; 0; 0];
end
