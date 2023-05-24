function matlabCode = extractMATFile(mlappFullPath)

    % input validation
    [mPath, mFileName, mFileExt] = fileparts(mlappFullPath);
    if isempty(mPath)
        mPath = fileparts(which(mlappFullPath));
        mlappFullPath = fullfile(mPath, [mFileName mFileExt]);
    end

    % reader object
    try
        reader = appdesigner.internal.serialization.FileReader(mlappFullPath);
        matlabCode = reader.readMATLABCodeText();

    catch ME
        error(ME.message);
    end
end