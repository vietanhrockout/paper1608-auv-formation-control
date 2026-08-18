function paths = project_paths()
    % PROJECT_PATHS Canonical repository paths, anchored to this file.
    %
    % Keeping artifact and documentation locations here avoids depending on
    % MATLAB's current working directory and keeps the repository root clean.

    paths.project_root = fileparts(mfilename('fullpath'));
    paths.repo_root = fileparts(paths.project_root);

    paths.artifacts = fullfile(paths.repo_root, 'artifacts');
    paths.phase_c = fullfile(paths.artifacts, 'phase-c');
    paths.validation = fullfile(paths.artifacts, 'validation');
    paths.diagnostics = fullfile(paths.artifacts, 'diagnostics');
    paths.work = fullfile(paths.artifacts, 'work');
    paths.phase_c_work = fullfile(paths.work, 'phase-c');

    paths.docs = fullfile(paths.repo_root, 'docs');
    paths.scripts = fullfile(paths.repo_root, 'scripts');
end
