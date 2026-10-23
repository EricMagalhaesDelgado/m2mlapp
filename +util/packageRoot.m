function [rootFolder, packagePrefix] = packageRoot(fileFolder)
% Folders "+pkg" and "@cls" must never be added to the MATLAB path. Returns
% the folder that must be on the path and the package prefix (e.g. "auxApp.")
% needed to reference classes stored in fileFolder.

    arguments
        fileFolder {validators.mustBeScalarText}
    end

    rootFolder    = char(fileFolder);
    packagePrefix = '';

    while true
        [parent, name] = fileparts(rootFolder);
        if isempty(name) || ~startsWith(name, {'+', '@'})
            break
        end

        if name(1) == '+'
            packagePrefix = [name(2:end) '.' packagePrefix];
        end
        rootFolder = parent;
    end

end
