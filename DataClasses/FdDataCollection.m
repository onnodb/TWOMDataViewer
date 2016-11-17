classdef FdDataCollection < matlab.mixin.Copyable
    % FDDATACOLLECTION Stores an (unordered) collection of FdData objects
    %
    % This is a utility class for organizing and maintaining a collection
    % of FdData objects. In our case, each FdData object in the collection
    % contains one F,d curve measured at a particular magnesium concentration,
    % indicated by the object's "tags".
    %
    % NOTE: The collection cannot contain the same FdData object multiple
    % times.
    %
    % NOTE: This class is not necessarily optimized for high performance.
    % For small- to medium-sized collections (say, hundreds of FdData objects)
    % on a modern PC, performance should be satisfactory, but no guarantees
    % are made...

    properties (SetAccess = private)

        % Cell array of all contained FdData objects.
        items = {};

    end

    % ------------------------------------------------------------------------

    methods

        function [self] = FdDataCollection(varargin)
            % FDDATACOLLECTION Constructor
            %
            % SYNTAX:
            % fdc = FdDataCollection();
            % fdc = FdDataCollection(fd1, fd2, ...);
            %
            % INPUT:
            % fd1, fd2 = FdData objects.

            if ~isempty(varargin)
                self.add(varargin{:});
            end
        end

        function add(self, varargin)
            % ADD Add FdData objects to the collection, optionally associating the objects with a tag.
            %
            % SYNTAX:
            % fdc.add(fd1, fd2, ...)
            %   Add one or more FdData objects to the collection.
            %   You can also specify FdDataCollection objects; their
            %   contents will be added to this collection.
            % fdc.add(fd1, fd2, 'tagA', fd3, 'tagB', 'tagC')
            %   Add FdData/FdDataCollection objects 'fd1' and 'fd2' to this
            %   collection, and associate them with the tag 'tagA'.
            %   Then add 'fd3', and associate it with tags 'tagB' and 'tagC'.
            % fdc.add('skipduplicatecheck', ...)
            %   Skip checking for duplicates while adding items.
            %   (Major speed-up when adding a large number of items;
            %   intended for internal use).

            if length(varargin) >= 1 && ischar(varargin{1}) && ...
                    strcmpi(varargin{1}, 'skipduplicatecheck')
                skipDuplicateCheck = true;
                varargin = varargin(2:end);
            else
                skipDuplicateCheck = false;
            end

            lastItemsAdded = {};
            previousItemWasTag = false;

            for item = varargin
                if isa(item{1}, 'FdDataCollection')
                    % Adding the contents of an FdDataCollection
                    if previousItemWasTag
                        lastItemsAdded = {};
                    end

                    for j = 1:item{1}.length
                        if skipDuplicateCheck || ~self.has(item{1}.items{j})
                            self.items = [self.items item{1}.items(j)];
                        end
                        lastItemsAdded = [lastItemsAdded item{1}.items(j)]; %#ok
                    end
                elseif iscell(item{1})
                    % Adding the contents of a cell array
                    if previousItemWasTag
                        lastItemsAdded = {};
                    end

                    for j = 1:length(item{1})
                        if skipDuplicateCheck || ~self.has(item{1}{j})
                            self.items = [self.items item{1}(j)];
                        end
                        lastItemsAdded = [lastItemsAdded item{1}(j)]; %#ok
                    end
                elseif isa(item{1}, 'FdData')
                    % Adding an FdData object
                    if previousItemWasTag
                        lastItemsAdded = {};
                    end

                    % Store, if not in there already
                    if skipDuplicateCheck || ~self.has(item{1})
                        self.items = [self.items item];
                    end
                    lastItemsAdded = [lastItemsAdded item]; %#ok
                elseif ischar(item{1})
                    % Associating this tag with prior data objects
                    for tagItem = lastItemsAdded
                        tagItem{:}.addTag(item{1});
                    end
                    previousItemWasTag = true;
                else
                    error('FdDataCollection:invalidArgument', 'Invalid argument');
                end
            end
        end

        function applyToAll(self, fun)
            % APPLYTOALL Applies a function to all items in the collection.
            %
            % INPUT:
            % fun = function handle to a function that takes an FdData object
            %       as input, and returns an FdData object (possibly the same).
            %       Each item in the collection is replaced with the item
            %       returned by 'fun'.
            %
            % NOTE: Uses a parallelized 'parfor' loop for better performance.

            if ~isa(fun, 'function_handle')
                error('FdDataCollection:invalidArgument', 'Invalid argument: function handle expected');
            end

            iterItems = self.items;
            parfor i = 1:length(iterItems)
                iterItems{i} = fun(iterItems{i}); %#ok
            end
            self.items = iterItems;
        end

        function [allData] = concatenatedData(self)
            % CONCATENATEDDATA Returns the data from all items combined into one FdData object.
            %
            % NOTE: Metadata from the constituting FdData objects is not
            % preserved.
            %
            % OUTPUT:
            % allData = an FdData object with all data concatenated.

            % Figure out how many data points we'll have in the end, so we can
            % pre-allocate buffers of the appropriate size.
            bufSize = 0;
            for i = 1:length(self.items)
                bufSize = bufSize + length(self.items{i}.f);
            end

            % Pre-allocate buffer
            all_f = zeros(bufSize,1);
            all_d = zeros(bufSize,1);
            all_t = zeros(bufSize,1);

            % Concatenate datasets
            iBufPos = 1;
            for i = 1:length(self.items)
                curSize = length(self.items{i}.f);

                all_f(iBufPos:iBufPos+curSize-1) = self.items{i}.f;
                all_d(iBufPos:iBufPos+curSize-1) = self.items{i}.d;
                all_t(iBufPos:iBufPos+curSize-1) = self.items{i}.t;

                iBufPos = iBufPos + curSize;
            end

            allData = FdData('Concatenated data', all_f, all_d, all_t);
        end

        function [num] = length(self)
            % LENGTH Returns the number of items in the collection.

            num = numel(self.items);
        end

        function disp(self)
            % DISP Lists the contents of the collection.

            fprintf(' #    name                                          tags\n');
            fprintf('--------------------------------------------------------------------------------\n');
            for i = 1:length(self.items)
                fprintf('(%-3d) %-45.45s %-45.45s\n', ...
                        i, self.items{i}.name, self.items{i}.tagString ...
                        );
            end
        end

        function dispAll(self, varargin)
            % DISPALL Displays all objects in the collection.
            %
            % Calls "disp" on all FdData in the collection.
            %
            % EXAMPLE:
            % >> c.dispAll('full')
            %      Displays detailed information on each of the FdData objects.
            %      (The 'full' argument is passed on to "FdData.disp").

            for i = 1:length(self.items)
                self.items{i}.disp(varargin{:});
                fprintf('\n');
            end
        end

        function [c] = filter(self, fun)
            % FILTER Returns all items for which the function 'fun' returns true.
            %
            % INPUT:
            % fun = function handle to a function that takes an FdData object
            %       as input, and returns true/false.
            %
            % OUTPUT:
            % c = a new FdDataCollection containing only those FdData objects
            %       for which 'fun' has returned true.

            if ~isa(fun, 'function_handle')
                error('FdDataCollection:invalidArgument', 'Invalid argument: function handle expected');
            end

            c = FdDataCollection();

            for i = 1:length(self.items)
                if fun(self.items{i})
                    c.add('skipduplicatecheck', self.items{i});
                end
            end
        end

        function forAll(self, fun)
            % FORALL Calls a function for all items in the collection.
            %
            % INPUT:
            % fun = function that is called for each item in the collection,
            %       with the FdData object in question as its only argument.

            if ~isa(fun, 'function_handle')
                error('FdDataCollection:invalidArgument', 'Invalid argument: function handle expected');
            end

            for i = 1:length(self.items)
                fun(self.items{i});
            end
        end

        function [tagList] = getAllTags(self)
            % GETALLTAGS Returns a list of all (unique) tags associated with items in the collection.

            tagList = {};

            for i = 1:length(self.items)
                tagList = [tagList self.items{i}.tags]; %#ok
            end

            tagList = unique(tagList);
        end

        function [c] = getByMetaData(self, varargin)
            % GETBYMETADATA Returns all items that have particular metadata.
            %
            % All function arguments are passed on directly to
            % "FdData.hasMetaData"; see there for an explanation of the call
            % syntax.

            c = FdDataCollection();

            for i = 1:length(self.items)
                if self.items{i}.hasMetaData(varargin{:})
                    c.add('skipduplicatecheck', self.items{i});
                end
            end
        end

        function [fd] = getByName(self, name)
            % GETBYNAME Returns an FdData item with a specific name.
            %
            % If multiple items with the same name exist, only the first one
            % found is returned.
            % Name comparison is case-insensitive.

            for i = 1:length(self.items)
                if strcmpi(name, self.items{i}.name)
                    fd = self.items{i};
                    return;
                end
            end

            fd = [];
        end

        function [c] = getByTag(self, tagName)
            % GETBYTAG Returns all items that have a particular tag.
            %
            % INPUT:
            % tagName = string with the name of a tag.
            %
            % OUTPUT:
            % c = a new FdDataCollection containing only those FdData objects
            %       that have the tag 'tagName'.

            c = FdDataCollection();

            for i = 1:length(self.items)
                if self.items{i}.hasTag(tagName)
                    c.add('skipduplicatecheck', self.items{i});
                end
            end
        end

        function [tagList] = getCommonTags(self)
            % GETCOMMONTAGS Returns a list of all tags that are associated with *every* item in the collection.

            tagList = {};

            for i = 1:length(self.items)
                if i == 1
                    tagList = self.items{1}.tags;
                else
                    newTagList = {};
                    for tag = tagList
                        if self.items{i}.hasTag(tag{:})
                            newTagList = [newTagList tag]; %#ok
                        end
                    end
                    tagList = newTagList;
                end
            end
        end

        function [b] = has(self, item)
            % HAS Checks if the collection contains an item.
            %
            % INPUT:
            % item = an FdData object.

            b = any(cellfun(@(x) eq(item, x), self.items));
        end

        function [idx] = indexOf(self, item)
            % INDEXOF Returns the index of an item in the collection.
            %
            % INPUT:
            % item = an FdData object.
            %
            % OUTPUT:
            % idx = index of the item if found, or '[]' if not found.

            idx = find(cellfun(@(x) eq(item, x), self.items), 1, 'first');
        end

        function [c] = intersect(self, other)
            % INTERSECT Returns the intersection between this collection and another one.
            %
            % INPUT:
            % other = another FdDataCollection.
            %
            % OUTPUT:
            % c = a new FdDataCollection containing those FdData objects that
            %       are contained in both this and the "other" FdDataCollection.

            c = FdDataCollection();

            for i = 1:self.length
                if other.has(self.items{i})
                    c.add('skipduplicatecheck', self.items{i})
                end
            end
        end

        function [b] = isequal(self, other)
            % ISEQUAL Returns whether this collection and another one contain exactly the same elements.

            b = false;

            if self.length ~= other.length
                return
            end

            for i = 1:self.length
                if ~other.has(self.items{i})
                    return
                end
            end

            b = true;
        end

        function [b] = isempty(self)
            % ISEMPTY Checks if the collection is empty.

            b = isempty(self.items);
        end

        function [res] = map(self, fun)
            % MAP Returns an FdDataCollection/cell array of collection items as processed by a function.
            %
            % INPUT:
            % fun = function handle to a function that takes an FdData object
            %       as input, and returns something else.
            %
            % OUTPUT:
            % res = cell array or FdDataCollection (depending on the return
            %       type of 'fun'); or [] if the collection contains no items.
            %
            % NOTE: Uses a parallelized 'parfor' loop for better performance.

            if ~isa(fun, 'function_handle')
                error('FdDataCollection:invalidArgument', 'Invalid argument: function handle expected');
            end

            if isempty(self.items)
                res = [];
            else
                mapResult = cell(1,length(self.items));

                parfor i = 1:length(self.items)
                    try
                        mapResult{i} = fun(self.items{i}); %#ok
                    catch err
                        fprintf('!!! Error processing item #%d (%s)\n', i, self.items{i}.name);
                        throw(err);
                    end
                end

                if isa(mapResult{1}, 'FdData')
                    res = FdDataCollection();
                    res.add('skipduplicatecheck', mapResult);
                else
                    res = mapResult;
                end
            end
        end

        function replace(self, removedObj, newObj)
            % REPLACE Replaces an object in the collection with another one.
            %
            % INPUT:
            % removedObj = object to remove.
            % newObj = new object replacing the old one.

            idx = self.indexOf(removedObj);
            if ~isempty(idx)
                self.items{idx} = newObj;
            end
        end

        function remove(self, varargin)
            % REMOVE Remove items from the collection.
            %
            % SYNTAX:
            % fdc.remove(fd1, fd2, ...)
            %   Remove one or more FdData objects from the collection.
            %   You can also specify an FdDataCollection object; its contents
            %   will be removed from this collection.

            for item = varargin
                if isa(item{:}, 'FdDataCollection')
                    % Removing contents of an FdDataCollection

                    for j = 1:item{1}.length
                        self.remove(item{1}.items{j});
                    end
                elseif isa(item{:}, 'FdData')
                    % Removing an FdData item
                    idx = self.indexOf(item{:});
                    if isempty(idx)
                        warning('FdDataCollection:itemNotFound', 'Cannot remove item: Item not found');
                    else
                        self.items(idx) = [];
                    end
                else
                    error('FdDataCollection:invalidArgument', 'Invalid argument');
                end
            end
        end

        function [c] = subtract(self, other)
            % SUBTRACT Returns all items in this collection that are *not* part of another one.
            %
            % INPUT:
            % other = an FdDataCollection.
            %
            % OUTPUT:
            % c = a new FdDataCollection containing only those FdData objects
            %       that are *not* present in 'other'.


            c = self.copy();
            c.remove(other);
        end

        function [c] = union(self, other)
            % UNION Returns the union of this collection and another one.
            %
            % INPUT:
            % other = an FdDataCollection.
            %
            % OUTPUT:
            % c = a new FdDataCollection containing items from both this
            %       collection and 'other'.

            c = self.copy();

            for i = 1:other.length
                c.add(other.items{i});
            end
        end

    end % methods

end
