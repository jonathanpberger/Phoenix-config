BIN = /usr/local/bin

init:
	-Rm ~/.phoenix.js
	$(BIN)/coffee --bare --compile --literate Phoenix-config.litcoffee
	mv Phoenix-config.js ~/.phoenix.js
