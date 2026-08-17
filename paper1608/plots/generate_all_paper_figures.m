function generate_all_paper_figures(result_path, manifest_path)
    % GENERATE_ALL_PAPER_FIGURES
    % Renders the 6 physical-state figures (Figs. 2, 3, 6, 7, 8, 9) from a
    % real Phase C production dataset, per the correct paper mapping in
    % EQUATION_MAPPING.md / handoff.md and the GO given in
    % REVIEW_GPT_2026-08-17_R8.md and R9.md:
    %   Fig. 2 = 3D operational trajectory
    %   Fig. 3 = 2D planar (x-y) trajectory
    %   Fig. 6 = position tracking response (x,y,z) per AUV vs. desired
    %   Fig. 7 = formation distance (actual leader-relative, not chi)
    %   Fig. 8 = formation tracking error chi_i (6 components per AUV)
    %   Fig. 9 = sliding surface s_i (6 components per AUV)
    %
    % Figs. 4 (cost-to-go) and 5 (actor NN output) are NOT included here.
    % They remain provisional pending Issue M/K (critic-weight-projection
    % thrashing) and are intentionally out of scope for this rewrite --
    % see handoff.md/IMPLEMENTATION_STATUS.md. Do not add them to this
    % function without a fresh review pass.
    %
    % Per REVIEW_GPT_2026-08-17_R8.md's finding: this dataset does NOT
    % reproduce the exact T1*=5s reaching deadline (E_chi/E_s are still
    % large at t=5s; the small-neighborhood entry happens ~t=7.1-7.5s,
    % sustained by the combined T1*+T2*=10s horizon). Figs. 8 and 9 show
    % both the full 100s horizon and a zoomed [0,15]s transient with both
    % deadline markers so this is visible, not hidden.

    if nargin < 1 || isempty(result_path)
        result_path = fullfile(fileparts(fileparts(mfilename('fullpath'))), '..', 'phase_c_result_t100.mat');
    end
    if nargin < 2 || isempty(manifest_path)
        manifest_path = fullfile(fileparts(fileparts(mfilename('fullpath'))), '..', 'phase_c_manifest_t100.mat');
    end

    project_root = fileparts(fileparts(mfilename('fullpath')));
    addpath(genpath(project_root));

    dr = load(result_path);
    dm = load(manifest_path);
    res = dr.res;
    manifest = dm.manifest;
    params = res.params;

    fprintf('Computing per-timestep series (eta, chi, s, leader-relative distance) from %s ...\n', result_path);
    series = compute_phase_c_series(res);

    plots_dir = fileparts(mfilename('fullpath'));

    figs = struct( ...
        'fig2_3d_trajectory',            @() plot_fig2_3d_trajectory(series, manifest, params), ...
        'fig3_planar_trajectory',        @() plot_fig3_planar_trajectory(series, manifest, params), ...
        'fig6_position_tracking',        @() plot_fig6_position_tracking(series, manifest, params), ...
        'fig7_formation_distances',      @() plot_fig7_formation_distances(series, manifest, params), ...
        'fig8_formation_tracking_error', @() plot_fig8_formation_tracking_error(series, manifest, params), ...
        'fig9_sliding_surfaces',         @() plot_fig9_sliding_surfaces(series, manifest, params) ...
    );

    names = fieldnames(figs);
    for k = 1:numel(names)
        name = names{k};
        fprintf('Rendering %s ...\n', name);
        f = figs.(name)();
        out_path = fullfile(plots_dir, [name, '.png']);
        exportgraphics(f, out_path, 'Resolution', 150);
        close(f);
        fprintf('  saved %s\n', out_path);
    end

    fprintf('\nAll 6 physical-state figures (2,3,6,7,8,9) saved to %s\n', plots_dir);
    fprintf('Figs. 4-5 (cost-to-go, actor NN output) intentionally NOT generated -- provisional, see handoff.md.\n');
end
