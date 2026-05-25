function treeTable = treeCodeGeneration(matlabCode)

    parser     = util.MTreeCodeParser();
    treeStruct = parser.parseWithMTree(matlabCode);
    
    if numel(treeStruct) < 3
        error([ ...
            'An app must have at least three blocks:\n' ...
            '(a) PUBLIC PROPERTIES (components);\n'     ...
            '(b) PRIVATE METHODS (createComponents);\n' ...
            '(c) PUBLIC METHODS (construct/delete).' ...
        ])
    end
    
    % treeStruct >> treeTable
    requiredFields = {'Line', 'EndLine', 'Items'};

    treeStructClass = class(treeStruct);
    for ii = 1:numel(treeStruct)
        switch treeStructClass
            case 'struct'
                treeStructElement = treeStruct(ii);
            otherwise % 'cell'
                treeStructElement = treeStruct{ii};
        end

        fieldMissing = setdiff(requiredFields, fieldnames(treeStructElement));
        if ~isempty(fieldMissing)
            error('m2mlapp:treeCodeGeneration:MissingField', 'Required field missing')
        end

        treeTable(ii) = struct( ...
            'Access', treeStructElement.Access, ...
            'Type',    treeStructElement.Type, ...
            'Line',    treeStructElement.Line, ...
            'EndLine', treeStructElement.EndLine, ...
            'Items',   {treeStructElement.Items} ...
        );
    end
    treeTable = struct2table(treeTable);

end