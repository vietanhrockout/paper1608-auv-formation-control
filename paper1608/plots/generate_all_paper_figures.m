function generate_all_paper_figures(result_path, manifest_path, include_provisional_rl)
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
    % Figs. 4 (cost-to-go) and 5 (actor NN output) are PROVISIONAL and are
    % NOT rendered by default. Pass include_provisional_rl=true to also
    % render them into fig4_cost_to_go.png / fig5_actor_nn_output.png.
    % They are gated behind an explicit opt-in because, unlike the six
    % accepted physical-state figures, they do NOT quantitatively
    % reproduce the paper: see the header of plot_fig4_cost_to_go.m and
    % paper1608/verify/diagnose_stepS1_rl_figure_feasibility.m -- the
    % assumed delta_c=100 caps the cost-to-go ~2.2e5x below the paper's
    % 1e8 plateau (Issue N), and the critic's Chat goes negative although
    % a true cost-to-go is non-negative by construction (Issue M/K).
    % Both figures carry that caveat on the rendered image itself.
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
    if nargin < 3 || isempty(include_provisional_rl)
        include_provisional_rl = false;
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

    if ~include_provisional_rl
        fprintf(['Figs. 4-5 (cost-to-go, actor NN output) NOT generated -- provisional. ' ...
            'Call generate_all_paper_figures(res, man, true) to render them.\n']);
        return;
    end

    fprintf('\n--- PROVISIONAL RL figures (4,5) -- NOT a quantitative reproduction ---\n');
    fprintf('Computing RL/NN series (critic cost-to-go, actor basis + output) ...\n');
    rl = compute_phase_c_rl_series(res);

    rl_figs = struct( ...
        'fig4_cost_to_go',        @() plot_fig4_cost_to_go(rl, manifest, params), ...
        'fig5_actor_nn_output',   @() plot_fig5_actor_nn_output(rl, manifest, params) ...
    );
    rl_names = fieldnames(rl_figs);
    for k = 1:numel(rl_names)
        name = rl_names{k};
        fprintf('Rendering %s (PROVISIONAL) ...\n', name);
        f = rl_figs.(name)();
        out_path = fullfile(plots_dir, [name, '.png']);
        exportgraphics(f, out_path, 'Resolution', 150);
        close(f);
        fprintf('  saved %s\n', out_path);
    end
    fprintf(['\nFigs. 4-5 rendered WITH on-image provisional caveats. Do not present them as a\n' ...
        'quantitative reproduction of the paper''s Fig.4 scale -- see diagnose_stepS1_*.m.\n']);
end
