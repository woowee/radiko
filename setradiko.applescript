# arguments ;
#   item 1. "${target}"
#   item 2. "${titleis}"
#   item 3. "${artistis}"
#   item 4. "${albumis}"
#   item 5. "${ganreis}"
#   item 6. $(echo ${target_dateis} | cut -c1-4)
#   item 7. "${coverartis}"

on run argv
	set a to item 1 of argv
	set theFile to (a as POSIX file) as alias
	
	# set info
	tell application "iTunes"
		# make a track
		set aTrack to (add theFile)
		
		#try
		# title
		set name of aTrack to item 2 of argv
		# artist
		set artist of aTrack to item 3 of argv
		# album
		set album of aTrack to item 4 of argv
		# ganre
		set genre of aTrack to item 5 of argv
		# year
		set year of aTrack to item 6 of argv
		# artwork
		set theArtwork to read (POSIX file item 7 of argv) as picture
		set data of artwork 1 of aTrack to theArtwork
		
		# and "remember playback position"
		set bookmarkable of aTrack to true
		
		#on error
		
		#end try
	end tell
end run
