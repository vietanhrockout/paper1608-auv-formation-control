function reserve_bottom_margin(fig, frac, top_frac)
    % RESERVE_BOTTOM_MARGIN
    % Compresses every axes in FIG into the vertical band
    % [FRAC, 1-TOP_FRAC] so the bottom FRAC is free for annotation
    % textboxes and the top TOP_FRAC is free for the sgtitle. Without
    % this, a subplot's xlabel collides with the provenance/caveat boxes
    % used by the provisional Fig.4/Fig.5 renderers (which carry two
    % stacked boxes instead of one).
    %
    % The mapping is AFFINE (bottom edge and height are both scaled by
    % 1-FRAC-TOP_FRAC), not a fixed absolute subtraction. An absolute
    % subtraction works for a single-row figure but flattens a 3-row
    % subplot grid, where each axes is only ~0.22 figure-units tall to
    % begin with.

    if nargin < 3 || isempty(top_frac)
        top_frac = 0;
    end

    span = 1 - frac - top_frac;
    assert(span > 0, 'reserve_bottom_margin: frac+top_frac must be < 1');

    ax = findall(fig, 'Type', 'axes');
    for k = 1:numel(ax)
        p = get(ax(k), 'Position');
        set(ax(k), 'Position', [p(1), frac + p(2) * span, p(3), p(4) * span]);
    end
end
