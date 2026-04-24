# Description
This is a plugin for Adobe Lightroom Classic that marks photos in the chosen color using files in a folder or a text of the filenames that matches the name in the active catalog.

<img width="4630" height="2164" alt="Lightroom marker v2" src="https://github.com/user-attachments/assets/900c495a-65a5-4ea5-beab-1fbaf9a33770" />


# Usage
<b>For folders</b>: paste the folder path that contains the reference photos in the first text field. The plugin will try to find all photos inside the folder. For example:
Windows:
```
C:/Users/Eightren/Photos
```
Mac & Linux:
```
/Users/eightren/Pictures/2025
```
<b>For text lists</b> paste the list of files in the second text field. The plugin will remove hidden `\n` newlines and commas. Please use this format when pasting values:
```
8RN00123.dng
8RN00456.dng
8RN00789.dng
```
or
```
8RN00123.dng 8RN00456.dng 8RN00789.dng
```
You can tick the "Allow Partial Match" to match partial names to files. For example:
```
123
```
will match:
```
8RN000123.dng
SOX12300.dng
```
Notice: When using short text like `01`. It might mark many photos since it is a very common pattern in file names.

# How to install lightroom plugins
Watch this video: https://www.youtube.com/watch?v=x_Ntz--rhFk
