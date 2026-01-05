local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrView = import "LrView"
local LrBinding = import "LrBinding"
local LrFileUtils = import "LrFileUtils"
local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

_G.folder = ""
_G.color = "red"
_G.filesString = ""
_G.allowPartialMatch = false
_G.selectLockedFilesOnly = false
_G.onlyMatchCurrentFolder = true

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
    for word in _G.filesString:gmatch("%S+") do
        word = word:gsub("%..+$", "")
        table.insert(filesInString, word)
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
        local photoFullPath = photo:getRawMetadata("path")
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
		local activeCatalog = catalog:getAllPhotos()

		catalog:withProlongedWriteAccessDo( 
			{
				 title="Mark " .. _G.color,
				 func = loopThrough,
				 caption="Initializing plugin",
				 pluginName="Photo Marker",
				 optionalMessage = "Marks the photos in " .. _G.color,
			})
    end) -- end LrTasks.startAsyncTask
end


-- Function to display the folder path and file text dialog
LrFunctionContext.callWithContext('folderPathDialog', function( context )
    -- Create the view factory
    local f = LrView.osFactory()

    -- Create an observable property table
    local properties = LrBinding.makePropertyTable( context )
    properties.folderPath = ""  -- Initialize the folder path property
    properties.fileStrings = "" -- Initialize the files property
    properties.colors = {"red", "yellow", "green", "blue", "purple" }
    properties.chosenColor = "red"

    properties:addObserver("fileStrings", function()
        properties.fileStrings = properties.fileStrings:gsub("\n", " "):gsub(",", " ")
    end)
    
    -- Create the view hierarchy for the dialog
    local contents = f:column {
        spacing = f:control_spacing(),
        bind_to_object = properties,  -- Bind to the property table
        f:static_text {
            title = "Enter the folder path below",
        },
        f:edit_field {
            value = LrView.bind 'folderPath',  -- Bind the value to 'folderPath'
            width_in_chars = 50,  -- Width of the text field
            alignment = 'left',
            placeholder = "Paste folder address here",
        },
        f:checkbox {
            value = false,
            title = 'Select locked files only',
            action = function(state)
                _G.selectLockedFilesOnly = state
            end
        },
        f:static_text {
            title = "Optional: Enter file names below (with or without extensions and with spaces)",
        },
        f:edit_field {
            value = LrView.bind 'fileStrings',
            width_in_chars = 50,
            alignment = 'left',
            placeholder = "3903 3498 4928",
        },
        f:checkbox {
            value = false,
            title = 'Allow partial match',
            action = function(state)
                _G.allowPartialMatch = state
            end
        },
        f:checkbox {
            value = true,
            title = 'Only match and find photos on the currently opened folder',
            action = function(state)
                _G.onlyMatchCurrentFolder = state
            end
        },
        f:row {
            f:static_text {
                title = "Select color:",
            },
            f:combo_box {
                items = LrView.bind 'colors',
                width = 100,
                value = LrView.bind 'chosenColor',
            },
        },
        f:static_text {
            title = "\nIf you find this plugin useful, consider donating!\nPaypal: eightren@gmail.com\nGCash: 0915 387 8745\n\n",
        },
        f:static_text {
            title = 'https://eightren.com',
            size = 'small',
            mouse_down = function()
            local LrHttp = import 'LrHttp'
            LrHttp.openUrlInBrowser('https://eightren.com')
            end,
            text_color = import 'LrColor'( 0, 0, 1 ),
        },
        f:static_text {
            title ='Version 1.5',
            size = 'small',
        }
    }

    -- Display the dialog
    local result = LrDialogs.presentModalDialog({
        title = "Eightren's Auto-Color Marker",
        contents = contents,
    })

    -- After pressing OK, process the entered folder path
    if result == "ok" then
        local folderPath = properties.folderPath
        local fileStrings = properties.fileStrings
        _G.color = properties.chosenColor
        _G.filesString = properties.fileStrings
        
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
