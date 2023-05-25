function treeTable = treeCodeGeneration(matlabCode)

    parser     = util.MTreeCodeParser();
    treeStruct = parser.parseWithMTree(matlabCode);
    
    if numel(treeStruct) < 3
        error(['An app must have at least three blocks:\n' ...
               '(a) PUBLIC PROPERTIES (components);\n'     ...
               '(b) PRIVATE METHODS (createComponents);\n' ...
               '(c) PUBLIC METHODS (construct/delete).'])
    end
    
    % treeStruct >> treeTable
    treeTable  = struct('Access',    {}, ...
                        'Static',    {}, ... % Only for METHODS blocks
                        'Type',      {}, ...
                        'Items',     {}, ...
                        'Line',      {}, ...
                        'Column',    {}, ...
                        'EndLine',   {}, ...
                        'EndColumn', {});
    
    for ii = 1:numel(treeStruct)
        % Create a homogenous struct, turning possible struct2table 
        % conversion
        if ~isfield(treeStruct{ii}, 'Static')
            treeStruct{ii}.Static = -1;
        end

        treeTable(ii) = treeStruct{ii};
    end
    treeTable = struct2table(treeTable);

end