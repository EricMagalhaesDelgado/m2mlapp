classdef MTreeCodeParser
    %MTreeCodeParser parses user edited code and extracts code features
    %   Parses M code defined in a class definition block. Extracts legal
    %   code definition data and its position information (line number,
    %   column number, etc).

    % Copyright 2015-2022 The MathWorks, Inc.

    properties (Access = private)
        % code content to parse
        CodeContent;
        % handle to the parse tree provided by MTree
        Tree;
    end

    properties(Access = private, Constant)
        % default attributes for class properties
        PropertiesAttributes = struct( ...
            'Access', 'public');

        % default attributes for class methods
        MethodsAttributes = struct( ...
            'Access', 'public', ...
            'Static', false);
    end

    methods
        %------------------------------------------------------------------

        function obj = MTreeCodeParser()
            % constructor no-op
        end
        %------------------------------------------------------------------

        function code = parse(obj, codeToParse)
            % parses code passed in as a cell array of lines of code
            obj.CodeContent = codeToParse;
            code =  obj.parseWithMTree(obj.wrapContentWithClassDef());
        end

        function code = parseWithMTree(obj, text)
            % parses the code using mtree
            obj.Tree = mtree(text);
            % if there is a parse error MTREE will report a one node tree
            % with 'ERR' kind. In this case return the err string
            if(obj.Tree.count == 1 && strcmp(obj.Tree.kind(), 'ERR'))
                code = obj.Tree.string;
            else
                try
                    code = obj.extractClassComponents();
                catch e
                    error('appdesigner:MTreeCodeParser:UnhandldedMTREEStructure', e.message);
                end
            end
        end
        %------------------------------------------------------------------
    end

    methods(Access = private)
        %------------------------------------------------------------------

        function wrappedText = wrapContentWithClassDef(obj)
            % wraps the code to parse in a classdef block. Adds one line
            % to the end of the code to parse
            wrappedText = sprintf('classdef parseThisCode\n%s\nend', obj.CodeContent);
        end
        %------------------------------------------------------------------

        %------------------------------------------------------------------

        function  parsedCode = extractClassComponents(obj)
            % gets the component blocks allowed in a class def block and
            % parses them individually
            kinds = {'PROPERTIES', 'METHODS'};
            parsedCode = {};

            for i = 1:length(kinds)
                classComp = mtfind(obj.Tree, 'Kind', kinds{i});
                idxs = indices(classComp);
                for j = idxs
                    % parse each section
                    parsedCode{end+1} = obj.extractCodeItems(j, kinds{i});
                end
            end
        end
        %------------------------------------------------------------------

        function codeItem = extractCodeItems(obj, index, component)
            % for each kind of class component parse the code to get code
            % entitites
            import util.MTreeCodeParser;

            % if the class component has attributes add them to the struct
            % generated for each block
            classComponent = obj.Tree.select(index);
            classComponentTree = classComponent.Tree;
            % get the position information for the class component
            blockLine = classComponent.lineno;
            blockCol = classComponent.charno;
            [blockEndL, blockendC] = classComponent.lastone;

            attributes = [];
            attrNodes = mtfind(classComponentTree, 'Kind', 'ATTRIBUTES');
            if(~isempty(attrNodes))
                attributes = MTreeCodeParser.extractPVListItems(attrNodes.Arg);
            end

            switch component
                case 'PROPERTIES'
                    codeItem = obj.PropertiesAttributes;
                    codeItem = MTreeCodeParser.assignAttributes(codeItem, attributes);
                    codeItem.Type = 'PROPERTIES';
                    codeItem.Items = MTreeCodeParser.extractPVListItems(classComponentTree.Body);
                case 'METHODS'
                    codeItem = obj.MethodsAttributes;
                    codeItem = MTreeCodeParser.assignAttributes(codeItem, attributes);
                    codeItem.Type = 'METHODS';
                    codeItem.Items = MTreeCodeParser.extractMethods(classComponentTree.Body);
            end

            % adds the end position information for the block
            codeItem.Line = blockLine - 1;
            codeItem.Column = blockCol;
            codeItem.EndLine = blockEndL - 1;
            codeItem.EndColumn = blockendC;
        end
        %------------------------------------------------------------------
    end

    methods(Access = private, Static)
        %------------------------------------------------------------------

        function items = extractMethods(tree)
            % extracts functions from a methods block. Handles external
            % functions and inner functions

            import util.MTreeCodeParser;

            current = tree;
            items = {};
            while(~isempty(current))
                % get traditional function defined with 'function' keyword
                func = mtfind(current, 'Kind', 'FUNCTION');
                % get external functions defined with just the function
                % name
                proto = mtfind(current, 'Kind', 'PROTO');
                if(~isempty(func))
                    % loop over found functions to handle inner functions
                    for i = indices(func)
                        item = MTreeCodeParser.extractFunction(func.select(i));
                        items{end+1} = item;
                    end
                end
                if(~isempty(proto))
                    item = MTreeCodeParser.extractExternalFunction(proto);
                    items{end+1} = item;
                end
                current = current.Next;
            end
        end
        %------------------------------------------------------------------

        function item = extractFunction(func)
            % gets function arguments, output, name, position, and end
            % posiiton for functions defined in a function block

            import util.MTreeCodeParser;

            item = {};
            if(~isempty(func.Ins))
                item.Args = MTreeCodeParser.extractListItems(func.Ins);
            end
            if(~isempty(func.Outs))
                item.Outputs = MTreeCodeParser.extractListItems(func.Outs);
            end
            name =  func.Fname;
            item.Name = name.string;
            nameLine = name.lineno;
            nameCol = name.charno;
            item.NamePosition = [nameLine - 1, nameCol];
            % subtract one line beacuse of line added with classdef
            item.Position = [func.lineno - 1,  func.charno];
            [endL, endC] = func.lastone;
            item.EndPosition = [endL - 1, endC];
            item.External = false;
            parentIndex = indices(func.trueparent);
            if(strcmp(kind(func.trueparent),'METHODS'))
                 item.LocalFunction = false;
            else
                 item.LocalFunction = true;
            end
        end
        %------------------------------------------------------------------

        function item = extractExternalFunction(proto)
            % gets the name and position info for external/abstract
            % functions

            import util.MTreeCodeParser;

            item = {};
            if(~isempty(proto.Ins))
                item.Args = MTreeCodeParser.extractListItems(proto.Ins);
            end
            if(~isempty(proto.Outs))
                item.Outputs = MTreeCodeParser.extractListItems(proto.Outs);
            end
            name =  proto.Fname;
            item.Name = name.string;
            item.Position = [proto.lineno - 1,  proto.charno];
            item.External = true;
        end
        %------------------------------------------------------------------

        function items = extractPVListItems(tree)
            % gets the property value pairs for Properties, Attributes,
            % Events, etc defined in a class section
            current = tree;
            items = {};
            while(~isempty(current))
                item = {};
                name =  current.Left;
                value = current.Right;
                if(strcmp(name.kind, 'PROPTYPEDECL'))
                    item.Property.Name = string(name.VarName);
					propertyTypes = strings(name.VarType);
					if isempty(propertyTypes)
						item.Property.Type = "";
					else
						item.Property.Type = propertyTypes{1};
					end
				elseif(strcmp(name.kind, 'ATBASE'))
                    item.Property.Name = string(name.Left);
                    name = name.Left;
                else
                    item.Property.Name = name.string;
                end
                item.Property.Position = [name.lineno - 1, name.charno];
                if(~value.isempty)
                    item.Value.Name = value.tree2str;
                    item.Value.Position = [value.lineno - 1, value.charno];
                end
                items{end+1} = item;
                current = current.Next;
            end
        end
        %------------------------------------------------------------------

        function items = extractListItems(tree)
            % gets the lists of items in function signatures
            current = tree;
            items = [];
            while(~isempty(current))
                item = {};
                % check if the argument is a '~'
                if  strcmp(current.kind, 'NOT')
                    item.Name = '~';
                else
                    item.Name = current.string;
                end
                item.Position = [current.lineno - 1, current.charno];
                items{end+1} = item; %#ok<*AGROW>
                current = current.Next;
            end
        end
        %------------------------------------------------------------------

        function classComponent = assignAttributes(classComponent, attributes)
            % assigns the attributes to the class component by updating its
            % value or adding to the default content
            if ~isempty(attributes)
                for i = 1:length(attributes)
                    if(isfield(attributes{i},'Value'))
                        classComponent.(attributes{i}.Property.Name) = attributes{i}.Value.Name;
                    else
                        classComponent.(attributes{i}.Property.Name) = true;
                    end
                end
            end
        end
        %------------------------------------------------------------------
    end
end
