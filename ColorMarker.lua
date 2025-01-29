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

-- Function to retrieve the list of filenames from the folder (including subfolders)
function getFilenamesInFolder(folderPath)
    local filenames = {}
    
    -- Use LrFileUtils.recursiveFiles to get all files in the folder and subfolders
    for filePath in LrFileUtils.recursiveFiles(folderPath) do
        -- Only include files with image extensions (e.g., .jpg, .dng)
        if filePath:match("%.jpg$") or filePath:match("%.dng$") then
            local filename = LrPathUtils.leafName(filePath)  -- Get the filename without the path
            table.insert(filenames, filename:match("^(.-)%.%w+$"))
        end
    end

    return filenames
end

function loopThrough(context, progressScope)
	local markedCount = 0;
	local catalog = LrApplication.activeCatalog()
	local activeCatalog = catalog:getAllPhotos()
	local filenamesInFolder = getFilenamesInFolder(_G.folder)
	-- Loop through each photo in the catalog and compare filenames
	for _, photo in ipairs(activeCatalog) do
		-- Combine folder path and file name to create the full file path
		local photoFullPath = photo:getRawMetadata("path")
		local photoFileName = photo:getFormattedMetadata("fileName"):match("^(.-)%.%w+$")

		-- Compare with filenames in the folder
		for _, filename in ipairs(filenamesInFolder) do
			-- If the photo filename matches any file in the folder, mark it
			if filename == photoFileName then
				-- Mark the photo with a red flag
				photo:setRawMetadata("colorNameForLabel", _G.color)
				markedCount = markedCount + 1
                	-- Periodically yield to allow the UI to update
                if markedCount % 5 == 0 then
                    progressScope:setPortionComplete(markedCount, #filenamesInFolder)
                    progressScope:setCaption(string.format("%d photos marked", markedCount))
                    LrTasks.yield()  -- Allow UI to update
                end
				break  -- Exit loop once photo is marked
			end
		end
	end

	-- Notify user with the result
	-- if markedCount > 0 then
	-- 	LrDialogs.message("Success", markedCount .. " photos marked in red.", "info")
	-- else
	-- 	LrDialogs.message("Error", "No matching photos found in the catalog.", "critical")
	-- end


	-- Finish progress
	progressScope:done()
end

-- Function to mark files in the folder
function markFilesInFolder(folderPath)
    -- Start an asynchronous task
    LrTasks.startAsyncTask(function()

        -- Sanitize the folder path
        folderPath = sanitizeFolderPath(folderPath)

        -- Get the list of filenames in the folder (and subfolders)
		_G.folder = folderPath
		local filenamesInFolder = getFilenamesInFolder(_G.folder)

        if #filenamesInFolder == 0 then
            LrDialogs.message("Error", "No images found in the folder.", "critical")
            return
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


-- Function to display the folder path dialog
LrFunctionContext.callWithContext('folderPathDialog', function( context )
    -- Create the view factory
    local f = LrView.osFactory()

    -- Create an observable property table
    local properties = LrBinding.makePropertyTable( context )
    properties.folderPath = ""  -- Initialize the folder path property
    properties.colors = {"red", "yellow", "green", "blue", "purple" }
    properties.chosenColor = "red"

    -- Create the view hierarchy for the dialog
    local contents = f:column {
        spacing = f:control_spacing(),
        bind_to_object = properties,  -- Bind to the property table
        f:static_text {
            title = "Enter the folder path below:",
        },
        f:edit_field {
            value = LrView.bind 'folderPath',  -- Bind the value to 'folderPath'
            width_in_chars = 50,  -- Width of the text field
            alignment = 'left',
            placeholder = "Paste folder address here",
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
            title = "\nIf you find this plugin useful, consider donating!",
        },
        f:static_text {
            title = "Paypal: eightren@gmail.com\nGCash: 0915 387 8745\n\n",
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
    }

    -- Display the dialog
    local result = LrDialogs.presentModalDialog({
        title = "Eightren's Auto-Color Marker",
        contents = contents,
    })

    -- After pressing OK, process the entered folder path
    if result == "ok" then
        local folderPath = properties.folderPath
        _G.color = properties.chosenColor
        
        -- Sanitize the folder path
        folderPath = sanitizeFolderPath(folderPath)

        -- Validate if the folder path exists
        if folderPath == "" then
            LrDialogs.message("Error", "You must enter a valid path", "critical")
        elseif not LrFileUtils.exists(folderPath) then
            LrDialogs.message("Error", "The entered path does not exist:\n" .. folderPath, "critical")
        else
        --     LrDialogs.message("Success", "Valid path provided:\n" .. folderPath, "info")
            
            -- Process the files in the folder and mark them
            markFilesInFolder(folderPath)
        end
        LrDialogs.stopModalWithResult(LrView, "ok")
    end
end)
