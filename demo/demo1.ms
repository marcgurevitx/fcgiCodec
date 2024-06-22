clear
key.clear

displayWidth = 68
displayHeight = 26
message = "[Press Escape]"
col = 20
row = 13
movingRight = true
movingDown = true
delay = .5

prevMoveAt = -1/0
while true
	if key.pressed("escape") then break
	
	now = time
	if now - prevMoveAt > delay then
		prevMoveAt = now
		
		if movingRight then col += 1 else col -= 1
		if col < 0 then
			col += 2
			movingRight = true
		else if col + message.len >= displayWidth - 1 then
			col -= 2
			movingRight = false
		end if
		
		if movingDown then row -= 1 else row += 1
		if row < 0 then
			row += 2
			movingDown = false
		else if row >= displayHeight then
			row -= 2
			movingDown = true
		end if
		
		clear
		text.column = col
		text.row = row
		print message, ""
	end if
	
	yield
end while

clear
key.clear
