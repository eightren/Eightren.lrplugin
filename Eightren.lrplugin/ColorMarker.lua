local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrView = import "LrView"
local LrBinding = import "LrBinding"
local LrFileUtils = import "LrFileUtils"
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

_G.folder = ""
_G.color = ""
_G.filesString = ""
_G.allowPartialMatch = false
_G.selectLockedFilesOnly = false
_G.onlyMatchCurrentFolder = true
_G.rating = 0
_G.updateRating = false
_G.updateFlag = false
_G.flagValue = 0

-- Function to sanitize the folder path
function sanitizeFolderPath(path)
    -- Remove leading/trailing spaces
    path = path:match("^%s*(.-)%s*$")
    
    -- Replace any backslashes with forward slashes (standardize path format)
    path = path:gsub("\\", "/")
    
    -- Remove single quotes from the path
    path = path:gsub("'", "")
    
    -- Check if the path ends with a trailing slash, add if missing
    if not path:match("/$") then
        path = path .. "/"
    end
    
    -- Return the sanitized path
    return path
end

-- Checks if file is locked or not
function isFileLocked(filename)
    local file = io.open(filename, "r+")
    if file then
        file:close()
        return false  -- File is not locked
    else
        return true   -- File is locked
    end
end

-- Function to retrieve the list of filenames from the folder (including subfolders)
-- return empty array if folderPath is empty
function getFilenamesInFolder(folderPath)
    local filenames = {}
    
    if _G.folder ~= "" then
        -- Use LrFileUtils.recursiveFiles to get all files in the folder and subfolders
        for filePath in LrFileUtils.recursiveFiles(folderPath) do
            local filename = LrPathUtils.leafName(filePath)  -- Get the filename without the path
            if _G.selectLockedFilesOnly then
                if isFileLocked(filePath) then
                    table.insert(filenames, filename:match("^(.-)%.%w+$"))
                end
            else
                table.insert(filenames, filename:match("^(.-)%.%w+$"))
            end
        end
    end

    return filenames
end

function loopThrough(context, progressScope)
    local markedCount = 0
    local catalog = LrApplication.activeCatalog()

    -- Decide photo scope
    local activeCatalog
    if _G.onlyMatchCurrentFolder then
        local sources = catalog:getActiveSources()
        if sources and sources[1] then
            activeCatalog = sources[1]:getPhotos()
        else
            activeCatalog = {}
        end
    else
        activeCatalog = catalog:getAllPhotos()
    end

    local filesInString = {}
    for token in _G.filesString:gmatch("%S+") do
        local normalizedToken = token:gsub("%..+$", "")
        table.insert(filesInString, normalizedToken)
    end

    local filesToCheck = getFilenamesInFolder(_G.folder)

    -- Merge both arrays only if filesInString is not empty
    if #filesInString > 0 then
        for _, word in ipairs(filesInString) do
            table.insert(filesToCheck, word)
        end
    end

    -- Loop through each photo in the chosen scope
    for _, photo in ipairs(activeCatalog) do
        local photoFileName =
            photo:getFormattedMetadata("fileName"):match("^(.-)%.%w+$")

        for _, filename in ipairs(filesToCheck) do
            local isPartialMatch = false

            if _G.allowPartialMatch and
               string.find(string.lower(photoFileName), string.lower(filename)) then
                isPartialMatch = true
            end

            if filename == photoFileName or isPartialMatch then
                photo:setRawMetadata("colorNameForLabel", _G.color)
                if _G.updateRating then
                    -- If rating is 0, set to nil to avoid the "invalid rating" error
                    local ratingValue = _G.rating
                    if ratingValue == 0 then
                        ratingValue = nil
                    end
                    photo:setRawMetadata("rating", ratingValue)
                end
                -- Flag logic
                if _G.updateFlag then
                    photo:setRawMetadata("pickStatus", _G.flagValue)
                end
                markedCount = markedCount + 1

                if markedCount % 5 == 0 then
                    progressScope:setPortionComplete(markedCount, #filesToCheck)
                    progressScope:setCaption(
                        string.format("%d photos marked", markedCount)
                    )
                    LrTasks.yield()
                end
                break
            end
        end
    end

    progressScope:done()
end

-- Function to mark files in the folder
function markFiles(folderPath)
    -- Start an asynchronous task
    LrTasks.startAsyncTask(function()

        -- search folder path if it exists
        if folderPath ~= "" then
            -- Get the list of filenames in the folder (and subfolders)
            _G.folder = folderPath
            local filenamesInFolder = getFilenamesInFolder(_G.folder)

            if #filenamesInFolder == 0 then
                LrDialogs.message("Error", "No images found in the folder.", "critical")
                return
            end
        end

        -- Get the catalog
        local catalog = LrApplication.activeCatalog()

		catalog:withProlongedWriteAccessDo( 
			{
				 title="Marking photos...",
				 func = loopThrough,
				 caption="Initializing plugin",
				 pluginName="Photo Marker",
				 optionalMessage = "Marks the photos",
			})
    end) -- end LrTasks.startAsyncTask
end

local function sectionHeading(f, title, subtitle)
    return f:column {
        spacing = 2,
        fill_horizontal = 1,
        f:static_text {
            title = title,
        },
        f:static_text {
            title = subtitle,
            size = 'small',
        },
    }
end

local function labeledRow(f, label, control, note)
    local rows = {
        spacing = f:label_spacing(),
        fill_horizontal = 1,
        f:static_text {
            title = label,
            width = LrView.share("label_width"),
            alignment = 'right',
        },
        control,
    }

    if note then
        table.insert(rows, f:static_text {
            title = note,
            size = 'small',
        })
    end

    return f:row(rows)
end

local function paragraph(f, text)
    return f:static_text {
        title = text,
        fill_horizontal = 1,
        height_in_lines = 2,
    }
end


-- Function to display the folder path and file text dialog
LrFunctionContext.callWithContext('folderPathDialog', function( context )
    -- Create the view factory
    local f = LrView.osFactory()

    -- Create an observable property table
    local properties = LrBinding.makePropertyTable( context )
    properties.folderPath = _G.folder  -- Initialize the folder path property
    properties.fileStrings = _G.filesString -- Initialize the files property
    properties.chosenColor = _G.color -- Initialize the chosen color property
    properties.rating = _G.rating
    properties.updateRating = _G.updateRating
    properties.allowPartialMatch = _G.allowPartialMatch
    properties.selectLockedFilesOnly = _G.selectLockedFilesOnly
    properties.onlyMatchCurrentFolder = _G.onlyMatchCurrentFolder
    properties.updateFlag = false  -- Toggle for the flag
    properties.flagValue = 0       -- Default to "Unflagged"

    properties:addObserver("fileStrings", function()
        properties.fileStrings = properties.fileStrings:gsub("\n", " "):gsub(",", " ")
    end)
    
    -- Create the view hierarchy for the dialog
    local contents = f:column {
        spacing = f:control_spacing(),
        bind_to_object = properties,
        fill_horizontal = 1,

        f:column {
            spacing = 4,
            fill_horizontal = 1,
            f:static_text {
                title = "Eightren Lightroom Photo Marker",
            },
            f:static_text {
                title = "Match photos by filename or source folder, then apply label color and optional rating in one pass.",
                height_in_lines = 2,
                fill_horizontal = 1,
            },
        },

        f:separator { fill_horizontal = 1 },

        sectionHeading(
            f,
            "1. Choose What To Match",
            "Use either a filename list, a source folder, or both. Folder matches scan subfolders automatically."
        ),
        paragraph(
            f,
            "Paste filenames separated by spaces, commas, or line breaks. Extensions are optional and will be ignored during matching."
        ),
        labeledRow(
            f,
            "Filenames",
            f:edit_field {
                value = LrView.bind 'fileStrings',
                width_in_chars = 52,
                alignment = 'left',
                immediate = true,
                placeholder = "3903 3498 4928",
            }
        ),
        f:checkbox {
            value = LrView.bind 'allowPartialMatch',
            title = 'Allow partial filename matches',
        },
        paragraph(
            f,
            "Add a folder when the source files already exist on disk and you want this plugin to build the filename list for you."
        ),
        labeledRow(
            f,
            "Source folder",
            f:edit_field {
                value = LrView.bind 'folderPath',
                width_in_chars = 52,
                alignment = 'left',
                immediate = true,
                placeholder = "/Volumes/Shoot/Selects",
            }
        ),
        f:checkbox {
            value = LrView.bind 'selectLockedFilesOnly',
            title = 'Only select locked files from source folder',
        },

        f:separator { fill_horizontal = 1 },

        sectionHeading(
            f,
            "2. Define Search Scope",
            "Control whether matching runs only against current Lightroom source or across entire catalog."
        ),
        f:checkbox {
            value = LrView.bind 'onlyMatchCurrentFolder',
            title = 'Limit search to currently opened folder or collection',
        },

        f:separator { fill_horizontal = 1 },

        sectionHeading(
            f,
            "3. Choose Metadata To Apply",
            "Selected metadata will be written to every matched photo."
        ),
        labeledRow(
            f,
            "Color label",
            f:popup_menu {
                value = LrView.bind "chosenColor",
                items = {
                    { title = "No color", value = "" },
                    { title = "Red", value = "red" },
                    { title = "Yellow", value = "yellow" },
                    { title = "Green", value = "green" },
                    { title = "Blue", value = "blue" },
                    { title = "Purple", value = "purple" },
                },
            },
            "Leave as No color to clear existing labels."
        ),
        f:checkbox {
            value = LrView.bind "updateRating",
            title = 'Update star rating for matched photos',
        },
        labeledRow(
            f,
            "Rating",
            f:popup_menu {
                enabled = LrView.bind "updateRating",
                value = LrView.bind "rating",
                items = {
                    { title = "☆☆☆☆☆ (None)", value = 0 },
                    { title = "★☆☆☆☆", value = 1 },
                    { title = "★★☆☆☆", value = 2 },
                    { title = "★★★☆☆", value = 3 },
                    { title = "★★★★☆", value = 4 },
                    { title = "★★★★★", value = 5 },
                },
            }
        ),
        f:column {
            -- Flag Toggle
            f:checkbox {
                title = "Check if you want to update the flag",
                value = LrView.bind "updateFlag",
            },

            -- Flag Dropdown
            f:row {
                f:static_text { 
                    title = "Flag:", 
                    enabled = LrView.bind "updateFlag",
                    width = LrView.share "label_width" 
                },
                f:popup_menu {
                    value = LrView.bind "flagValue",
                    enabled = LrView.bind "updateFlag",
                    items = {
                        { title = "Flagged", value = 1 },
                        { title = "Unflagged", value = 0 },
                        { title = "Rejected", value = -1 },
                    },
                },
            },
        },

        f:separator { fill_horizontal = 1 },

        sectionHeading(
            f,
            "About",
            "Built by Eightren. Support development if this tool saves time in your workflow."
        ),
        f:static_text {
            title = "Donations: PayPal eightren@gmail.com   |   GCash 0915 387 8745",
            fill_horizontal = 1,
        },
        f:row {
            spacing = f:label_spacing(),
            f:static_text {
                title = 'https://eightren.com',
                size = 'small',
                mouse_down = function()
                    local LrHttp = import 'LrHttp'
                    LrHttp.openUrlInBrowser('https://eightren.com')
                end,
                text_color = import 'LrColor'(0, 0, 1),
            },
            f:static_text {
                title = 'Version 2.0',
                size = 'small',
            },
        },
    }

    -- Display the dialog
    local result = LrDialogs.presentModalDialog({
        title = "Eightren Lightroom Photo Marker",
        contents = contents,
        actionVerb = "Mark Photos",
    })

    -- After pressing OK, process the entered folder path
    if result == "ok" then
        local folderPath = properties.folderPath
        local fileStrings = properties.fileStrings
        _G.color = properties.chosenColor
        _G.filesString = properties.fileStrings
        _G.rating = properties.rating
        _G.updateRating = properties.updateRating
        _G.allowPartialMatch = properties.allowPartialMatch
        _G.selectLockedFilesOnly = properties.selectLockedFilesOnly
        _G.onlyMatchCurrentFolder = properties.onlyMatchCurrentFolder
        _G.updateFlag = properties.updateFlag
        _G.flagValue = properties.flagValue
        
        -- Sanitize the folder path
        if folderPath ~= "" then
            folderPath = sanitizeFolderPath(folderPath)
        end

        -- Validate if the folder path exists when fileStrings is empty
        if folderPath == "" and fileStrings == "" then
            LrDialogs.message("Error", "You must enter valid values", "critical")
        elseif not LrFileUtils.exists(folderPath) and fileStrings == "" then
            LrDialogs.message("Error", "The entered path does not exist:\n" .. folderPath, "critical")
        else
        --     LrDialogs.message("Success", "Valid path provided:\n" .. folderPath, "info")
            
            -- Process the files in the folder and mark them
            markFiles(folderPath)
        end
        LrDialogs.stopModalWithResult(LrView, "ok")
    end
end)
