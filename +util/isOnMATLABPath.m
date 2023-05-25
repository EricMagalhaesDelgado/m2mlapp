function Status = isOnMATLABPath(fileFolder)

    arguments
        fileFolder {validators.mustBeScalarText}
    end

    fileFolder = char(lower(fileFolder));
    MATLABPath = strsplit(lower(path), ';');

    if ismember(fileFolder, MATLABPath)
        Status = true;
    else
        Status = false;
    end

end