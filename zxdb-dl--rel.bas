'!ORG=32768
'!HEAP=2048
'!PC=0
'!BMP=loading2.bmp
'!nosys
'!noemu
'#!copy=h:\zxdb\zxdb-dl.bin

' source for zxdb-dl - em00k/2021

' border 0 

backupsysvar() 

#include <nextlib.bas>
#include <keys.bas>
#include <string.bas>

paper 0 : ink 7 : border 0 : cls 


WaitKey()
ShowLayer2(0)

'-- Reg setup 
asm 
	nextreg NEXT_RESET_NR_02,0              		; wifi on 
	nextreg PERIPHERAL_3_NR_08,$fe              		; no contention 
	nextreg TURBO_CONTROL_NR_07,3                       ; 28mhz 
	nextreg CLIP_TILEMAP_NR_1B,0                        ; Tilemap clipping 
	nextreg CLIP_TILEMAP_NR_1B,159
	nextreg CLIP_TILEMAP_NR_1B,0
	nextreg CLIP_TILEMAP_NR_1B,255
	NextReg TILEMAP_DEFAULT_ATTR_NR_6C,%00000000        ; tilemap on & on top of ULA,  80x32 
	NextReg TILEMAP_CONTROL_NR_6B,%11001001				; tilemap on & on top of ULA,  80x32 
	NextReg TILEMAP_BASE_ADR_NR_6E,$44				    ; tilemap data $4400
	NextReg TILEMAP_GFX_ADR_NR_6F,$40				    ; tilemap blocks 4 bit tiles $4000
	NextReg PALETTE_CONTROL_NR_43,%00110000
end asm 

dim idnum,tchar, quit, tcar,char,v,xx,yy,option,options,keydown,col,done,tindex,tries as ubyte 
dim rowyy,results,k, offset,update,tempbyte,page,baud,a as ubyte 
dim currTY as ubyte = 18
dim start as ubyte = 1
dim espflag as ubyte = baud 
dim machine$(4) as string 
dim format$(4) as string 

dim s$,dot$,history$,appdir$,split$,term$,mainsrch$ as string 
dim tempcar$,helptextin$ as string 
dim peekstringcount, totlen,spos,tcount,psize as uinteger
dim t$,ext$,filestring as string 
dim id$,name$,desc$,auth$,date$,hits$,file$,strsize$ as string 
dim sizefile$,oldsearch$ as string 
dim b$,path$ as string 
dim l,size,bigsize as ulong

#define MP3DOS(COMMAND,BANK) \
	exx \
	ld de,COMMAND \
	ld c,BANK \
	rst $08 \
	db $94

asm 
	di 
end asm 
page = 1
option = 0
rowyy = 5           '  start of search results 
baud = 0 


zx7Unpack(@palettezx7,$4000)                                    ' LoadSD("out.pal",$7000,512,0)
PalUpload($4000,64,0)											' upload the palette 
zx7Unpack(@fontzx7,$4000)                                       ' LoadSD("font.bin",$4000,4096,0) '; font 
cleartilemap() 

machine$(0)="?"
machine$(1)="128k"
machine$(4)="48k"

format$(0)="TAP"
format$(1)="TZX"
format$(2)="SNA"
format$(3)="Z80"
format$(4)="?"

idnum=36

clearsection()
ver$="v0.97e"
mainsrch$="http get -x -b 20 -h zxdb.remysharp.com -u /v2/?s="
restore infoscreen
TextScreen()

' no longer required 
' file$="c:/dot/http" : GetFileSize() 
' bigsize = 1

' if bigsize = 0
'     AddText("ERROR : Missing c:/dot/http",2)
'  	AddText("Saving copy...",0)
' 	SaveHTTP()
' endif 

GetCWD() : appdir$=path$ : AddText(path$,6)
' LoadCFG() : AddText("Loaded config",6)
SetSpeed(baud)

' attempt to flush uart 
AddText("Downloading dummyfile from zxbasic.uk/uploads/8kilo.bin to flush UART",6)
dot$="http get -x -b 22 -h zxbasic.uk -u /uploads/8kilo.bin -v 1" : ExecDot(dot$)

' get save dir from cfg 

AddText("Save dir : "+path$,3)
GetHTTPver()
AddText("Type a search term and press enter.",14)

' main loop 

do 
	
	' border 0 

	do 
		if quit = 0 
			'if start = 1 
				start = 0 
				' search 
				t$=""
				keydown = 1  
				AddText("Search : _ ",5)
				TileInput(9,currTY,t$)
				if len(t$)>0 
					AddText("Searching for : "+t$,13)
					ShowHeader()
					term$=t$
					page = 0
					'dot$="http get -b 20 -h zxdb.remysharp.com -u /?s="+t$+" -f /tmp/tmp.dat"
					dot$=mainsrch$+t$+" -v 1"
					oldsearch$=dot$
					quit = 1 
					option = 3 
					tries = 0 
				endif 	
			'endif 
		endif 
	loop until quit = 1
	
	' 
	' now process the options 
	' 

	if option = 1 			                        ' we want to download 

		' check did we already download?
		bigsize = 0
		GetFileSize() 			                    ' populates bigsize ulong from file$

		if bigsize = size 
			AddText(sizefile$+" - Looks like we already have this file!",12)
			option = 4 : keydown = 1 
		else 
			DownloadFile(file$)
			option = 4
		endif 
		
		if bigsize <>size							' does the download size not match the filesize?
			
			tries = 4

			do 
		 		AddText("Retry "+str(4-tries)+"/4 - size mismatch : received "+str(bigsize)+", expected "+str(size),1)
				DownloadFile(file$)
				GetFileSize() 			' populates bigsize ulong 
				tries = tries - 1 
			loop until bigsize = size or tries = 0

			if bigsize = size
				AddText("Downloaded "+str(bigsize)+" bytes - sizes match! ",5)

					option=4
					quit = 1

			else 
				option = 2

			endif 
		else 
			' sizes match 
			AddText("Downloaded "+str(bigsize)+" bytes - sizes match! ",5)
			option=4
			quit = 1
		endif 


	endif 

	if option = 2 		' failure 
	
		AddText("Failed to download "+file$,16)
		AddText("R to retry or any key to continue",3)
		do 
			k = code inkey
			if k = code "r" 
				option=1 : quit = 1
				exit do 
			elseif k>0 
				option=0
				quit = 0
				exit do 
			endif 
		loop 
	endif 
	
	if option = 3                   ' reprocess search results 
		
		dot$=oldsearch$
		ShowHeader()
		ProcessSearch()

	endif 
	
	if option = 5					' do selector loop 	
		AddText("Use Cursor UP/DOWN, Cursor LEFT/RIGHT next/prev page",3)	
		AddText("ENTER to download, s to search",3)		
		Selector()                  ' offset will be set here 
		if option = 1 
			SelectID()
		endif 
	endif 

	if option = 4                   ' choose to play game or not 
		PlayGame()
	endif 

	if option = 6 					' to view screen # not implemented 
		option = 0 : quit = 0 
	endif 

	if option = 7                   ' update 
		changedir(appdir$)

		clearsection()
		dot$="rm zxdb-dl.nex" : ExecDot(dot$)
		AddText("Changing dir to "+appdir$,4)
		dot$="http get -x -h zxbasic.uk -u /zxdb-dl/zxdb-dl.nex -f zxdb-dl.nex -v 2"
		ExecDot(dot$)
		file$="zxdb-dl.nex" : GetFileSize()
		if bigsize>0
			dot$="mv -f zxdb-dl.nex zxdb-dl.bin" : ExecDot(dot$)
			dot$="rm zxdb-dl.nex" : ExecDot(dot$)
			AddText("Downloaded update OK, please restart!",13+16)
			WaitKey()
			asm
				rst 0 
			end asm 
		else 
			AddText("Error downloading update",13+16)
		endif 
		
	endif 

	 if option = 10 
		asm 
		nextreg NEXT_RESET_NR_02,128              		; wifi off
		nextreg TILEMAP_CONTROL_NR_6B,%00000000
		nextreg TURBO_CONTROL_NR_07,0
		end asm 
		restoresys()
	 	stop 
	 endif 
loop 

sub ShowHeader()
	' displays the screens header info 
	clearsection()
	TextBlock(0,1,"Search results for : ",5)
	TextBlock(23,1,t$,2)
							
	TextBlock(0,2,"--------------------------------------------------------------------------------",7)
	TextBlock(0,3,"ID  Name                      Size   Year     Filename",13)
	TextBlock(0,4,"--------------------------------------------------------------------------------",7)
end sub

sub PlayGame()
	' launches a game 
	colourrow(32)
	AddText("Enter to play, c to change SaveDir or any other key to continue",13+16)
	' border 0 
	keydown=1
	do 
		k = code inkey 
		if k and keydown = 0 
			if k = 13 				' enter 
				ProcessFile(file$)
			elseif k = code "c" 		' change save dir 
				t$="#cd" 
				Directive()
				t$=oldsearch$
				quit = 1
				exit do
			else
				exit do 
			endif  	
			keydown = 1 
		elseif k = 0 
			keydown = 0 
		endif 	
	loop 
	option = 5              ' reprocess search results 
end sub

sub ProcessSearch()

	asm 
		; ensures bank is empty 
		nextreg NEXT_RESET_NR_02,0              		; wifi on
		nextreg $57,40
		ld hl,$e000 : ld (hl),0
		ld de,$e001 : ld bc,$2000 : ldir 
		nextreg $57,1
	end asm 

	ExecDot(dot$)									'; executes search command
	' border 0 
	MMU8(7,40)
	SplitString($e000,code "^",offset+3)
	
	dim ty,a,fc as ubyte 
	dim offset,temp as uinteger

	' we have the data from the server in $e000, bank 40 
	' so we need to parse it 

   if peek($e000)<>$0a and peek($e000)<>$00
		ty=5
		while offset<70

			SplitString($e000,code "^",offset+2)	            ' get name, ^ is the delim 
			PeekString2(@stringtemp,name$)                      ' send the returned string back to name$ 
			if peek(@stringtemp)=0 : exit while : endif

				SplitString($e000,code "^",offset+3)	        ' get filename 
				PeekString2(@stringtemp,file$)
				
				a = code (right(file$,1))

				if a = code "p" 	' tap 
				'	format$="TAP" 
					a = 0 
					fc = 4 
				elseif a = code "x" 
				'	format$="TZX" 
					a = 1
					fc = 13
				elseif a = code "a"
				'	format$="SNA"
					a = 2
					fc = 13
				elseif a = code "0" 
				'	format$="Z80" 
					a = 3 
					fc = 13 
				else 
					a = 4 
				'	format$="?"
				endif 

				SplitString($e000,code "^",offset+4)	      ' get file size 
				'strsize$=PeekString(2+@stringtemp)
				PeekString2(@stringtemp,strsize$)

				SplitString($e000,code "^",offset+6)	      ' get file year 
				'year$=PeekString(2+@stringtemp)
				PeekString2(@stringtemp,year$)

				SplitString($e000,code "^",offset+7)	
				'id$=PeekString(2+@stringtemp)
				PeekString2(@stringtemp,id$)
				idnum = val (id$)
				' game name 
				'TextBlock(0,ty,id$,0)
				TextBlock(0,ty,machine$(idnum),0)
				TextBlock(4,ty,name$( to 26),6)
				' id of download 
				TextBlock(30,ty,strsize$,9)
				TextBlock(37,ty,year$,10)
				TextBlock(42,ty,format$(a),fc)			' fc = format colour 

				TextBlock(46,ty,file$( to 33),11)
				'TextBlock(30,ty,str(offset)+" "+size$+" "+file$,11)
				
				offset=offset+8
				ty=ty+1 
				
		end while  

		offset=offset+7
		results = ty

		if results-5 = 0 
			option = 0 : quit = 0 
			else
			option = 5 
		endif 
		TextBlock(0,ty+1,"Page : "+str(page+1)+" / Results : "+str(results-5),14)

	elseif page >= 1
		' if page > 0 and no results then go back a page 
		AddText("No more results ",9)
		page = page - 1
		oldsearch$=mainsrch$+term$+"&p="+str(page)+" -v 1"
	'	AddText(oldsearch$,9)
		option = 3 : quit = 1

	elseif page = 0 
		' if we're on page 0 
		AddText("Retry for results",3)
		tries = tries + 1
		if tries < 3 
			oldsearch$=mainsrch$+term$+"&p="+str(page)+" -v 1"
			option = 3 : quit = 1
		else 
			TextBlock(0,5,"No results",1)	
			option = 0 : quit = 0 
		endif 

	endif
	
	MMU8(7,1)

end sub 

sub SelectID()

	' checks ID entered is between 0 and 15 

	if offset >=0 and offset <16
		offset = (8*offset) 
		asm : nextreg $57,40 : end asm 
		' name$=SplitString(s$,"^",2+offset)
		'file$=SplitString(s$,"^",3+offset)
		SplitString($e000,code "^",3+offset)	      ' get file file$ 
		'file$=PeekString(2+@stringtemp)
		PeekString2(@stringtemp,file$)

		'id$=SplitString(s$,"^",1+offset)
		SplitString($e000,code "^",1+offset)	      ' get file id
		'id$=PeekString(2+@stringtemp)
		PeekString2(@stringtemp,id$)

		'strsize$ = SplitString(s$,"^",4+offset)
		SplitString($e000,code "^",4+offset)	      ' get file size
		'strsize$=PeekString(2+@stringtemp)
		PeekString2(@stringtemp,strsize$)

		SplitString($e000,code "^",7+offset)	      ' get file size
		'loader$=PeekString(2+@stringtemp)
		PeekString2(@stringtemp,loader$)

		if loader$="1"
			loader$="1 - 128K mode"
		elseif loader$="4"
			loader$="4 - 48K "
		elseif loader$="0"
			loader$="0 - USR 0"
		elseif loader$="N"
			loader$="N - Next"
		else 
			loader$="0 - USR 0" 
		endif 

		size = val(strsize$)

		AddText("File : "+file$+" ",2)
		AddText("ID   : "+id$,3)
		AddText("Size : "+strsize$,4)
		AddText("Recommended loader : "+loader$,5+16)

		dot$="http get -x -h zxdb.remysharp.com -u /v2/get/"+id$+" -f "+file$+" -v 2"

		asm : nextreg $57,1 : end asm 
		option=1                    ' download 
		quit = 1 
	else
		quit = 0
		option = 0
	endif 

end sub



sub Selector()

	colourrow(32)
	keydown = 1 
	do 

		k = code inkey 
		if k and keydown = 0  
			if  k = 10          ' cursor down 
				if rowyy<results-1 
					rowyy=rowyy+1 : colourrowdown(32)
				endif 
				
			elseif k = 11       ' cursor up 
				if rowyy>5
					rowyy=rowyy-1 : colourrowup(32)
				endif 
			elseif k = 102       ' f

				AddText("Loading Screen : ",3)
				offset = rowyy-5 
				option = 6 
				exit do 
			elseif k = 13       ' return
				' AddText("ID "+str(rowyy-5),2)
				offset = rowyy-5 
				option = 1
				exit do 
			
			
			elseif k = 8       ' left 
				' This will get the previous page if > 1
			   	if page > 0
				   AddText("Requesting previous page...",6)
			   		page = page - 1 : 
					oldsearch$=mainsrch$+term$+"&p="+str(page)+" -v 1"
					
					option = 3					' process search 
			   		exit do 
				endif 

			elseif k = 9       ' Right 
				' AddText("ID "+str(rowyy-5),2)
				if results-5 =9
					page = page + 1 
					AddText("Requesting next page...",6)
					oldsearch$=mainsrch$+term$+"&p="+str(page)+" -v 1"
					'AddText(oldsearch$,3)
					option = 3 	' process search 		
					exit do 	
				endif 
			   
			elseif k = 115       ' s to find 
				colourrow(32)
				rowyy = 5 
				offset = 16 
				update = 0 
				quit = 0 
				exit do 

			endif

			keydown = 1 
		   
		elseif k = 0 

			keydown = 0 
		endif 
		
	loop 

end sub     


Sub DownloadFile(file$)
		' downloads file with http
		AddText("Downloading "+file$,6)	
		ExecDot(dot$)
end sub 

sub AddText(intext$ as string, colour as ubyte)
	' adds text to display 
	currTY=currTY+1 
	if currTY>24
		asm
			ld hl,$4400+(19*160)
			ld de,$4400+(18*160)
			ld bc,7*160
			ldir 
	   end asm 
		currTY=currTY-1
	endif 
	TextBlock(0,currTY,intext$,colour)
end sub


Sub TileInput(txx as ubyte, tyy as ubyte,ret$ as string)
	
	' simple input routine, output in t$

	dim k as ubyte 
	dim cf as ubyte												' cursor flash 
	t$="" : cursor$="_ "
	keydown = 1 												' ensure we loop delay until no keys are pressed 
	WaitRetrace(100)											' delay 
	do 
		
		k = code inkey 
		if k and keydown = 0 											' first run skipped 
			if k>31 and k < 127									' normal ascii 
				t$=t$+chr k 	
				TextBlock(txx,tyy,t$+"_",5)						' update screen 
				keydown = 1 
			elseif k=12     ' delete 
				t$=t$( to len(t$)-2)
				TextBlock(txx,tyy,t$+"_ ",5)
				keydown = 1 
			elseif k = 13 
				TextBlock(txx,tyy,t$( to len(t$)-1)+" ",5)
				history$=t$ 
				exit do 
			elseif k = 11				' cursor up 
				t$=history$
				TextBlock(txx,tyy,t$+"_",5)						' update screen 
				keydown = 1 
			else 
				keydown = 1 
			endif 
		elseif k = 0  						
			keydown = 0 
		endif 
		
		WaitRetrace(1)

		if cf = 0 
			TextBlock(txx,tyy,t$+"_",5)
			cf = 20 
		elseif cf=10 
			TextBlock(txx,tyy,t$+" ",5)
			cf=cf-1
		else 
			cf=cf-1
		endif 
	
	loop 

	if t$(0)="#" 
		Directive()
	endif 
	
	' border 0
end sub 

sub Directive()
	dim tb as ubyte 
	option = 0 : quit = 0 
	if t$="#update"
		AddText("Downloading update",5)
		option = 7 : quit = 1 
	elseif t$(1)="s"
		tb = val (t$(2))
		if tb>=0 and tb<=6
			SetSpeed(tb)
			SaveCFG()
		endif 
	elseif t$(1 to 2)="cd"
	 	if len(t$(4 to ))>0
		 	AddText(str(len(t$(4 to ))),4)
	 		changedir(t$(4 to ))
		else 
			' poke $5c08,0
		 	browserdir()
		endif 
		'AddText(t$,6)
		GetCWD() 
		'AddText(path$,6)
		if tempbyte = 0 
			AddText("Save dir : "+path$,6)	
			'SaveSD("c:/sys/zxdb.cfg",peek(uinteger,@path$),len(path$)+2)					
			SaveCFG()
		else 
			AddText("Error changing path",4)
		endif  
	elseif t$="#cpm"
		dload$="http://www.cpm.z80.de/download/cpm3bin_unix.zip"	
		dot$="http get -x -h www.cpm.z80.de -u /download/cpm3bin_unix.zip -f cpm3bin_unix.zip -v 2"
		file$="cpm3bin_unix.zip"
		DownloadFile(file$)
		GetFileSize()
		AddText("downloaded "+str(bigsize),6)
		option = 0 : quit = 0
	' elseif t$="#http"
	' 	SaveHTTP()
	' 	option = 0 : quit = 0
	elseif t$="#ver"
		GetHTTPver()
	elseif t$(1)="q" 
	 	option = 10 : quit = 1 
	endif 
	t$=""
end sub

sub ProcessFile(file$)
	ext$=Lcase(Right(file$,3))
	cls : ' border 0
	asm
		; nextreg NEXT_RESET_NR_02,128              		; wifi off
		nextreg TILEMAP_CONTROL_NR_6B,%00000000
		nextreg TURBO_CONTROL_NR_07,0
	end asm 
	restoresys()
	'zx7Unpack(@sysvar,$5C00)
	asm 

	end asm 
	if ext$="tap"
		
		dot$="tapein "+file$
		ExecDot(dot$)
		asm 
			ei 
		end asm 
		executebasic("clear 65367 : load "+chr(34)+"c:/nextzxos/tapload.bas"+chr(34)+" :  let f$="+chr(34)+file$+chr(34)+" : goto 10")
	elseif ext$="tzx"
		asm 
			ei 
		end asm 
		executebasic("clear 65367 :  load "+chr(34)+"c:/nextzxos/tzxload.bas"+chr(34)+" :  let f$="+chr(34)+file$+chr(34)+" : goto 10")
	elseif ext$="sna" or ext$="snx" or ext$="z80"
	
		SNAPLOAD(file$)
	elseif ext$="nex"
		
		dot$="nexload "+file$
		ExecDot(dot$)
	elseif ext$="bin"
		executebasic("goto 10")
	endif 
end sub 

sub SetSpeed(choice as ubyte)
	
	baud = choice 

	b$="115200"
	if baud = 0 
		b$="115200"
	elseif baud = 1 
		b$="57600"
	elseif baud = 2 
		b$="19200"
	elseif baud = 3 
		b$="230400"
	elseif baud = 4 
		b$="460800"
	elseif baud = 5 
		b$="576000"
	elseif baud = 6 
		b$="1152000"
	endif 
	AddText("Baud set to : "+b$,8)
	dot$="espbaud -dq "+b$ 
	ExecDot(dot$)
end sub 

sub GetFileSize()

	' ; ***************************************************************************
	' ; * F_STAT ($ac) *
	' ; ***************************************************************************
	' ; Get unopened file information/status.
	' ; Entry:
	' ; A=drive specifier (overridden if filespec includes a drive)
	' ; IX [HL from dot command]=filespec, null-terminated
	' ; DE=11-byte buffer address
	' ; Exit (success):
	' ; Fc=0
	' ; Exit (failure):
	' ; Fc=1
	' ; A=error code
	' ;
	' ; NOTES:
	' ; The following details are returned in the 11-byte buffer:
	' ; +0(1) drive specifier
	' ; +1(1) $81
	' ; +2(1) file attributes (MS-DOS format)
	' ; +3(2) timestamp (MS-DOS format)
	' ; +5(2) datestamp (MS-DOS format)
	' ; +7(4) file size in bytes


	asm 

	nsetdrive:
			
			ld      hl,(._file)
			ld      c,(hl)
			inc     hl               
			ld      b,(hl)                                                   ; bc string length
			ld      a,c 
			or      b 
			jr      z,donefsizefs 
			inc     hl 											            ; move along to start of string 
			ld      de,.LABEL._filename
			ldir : ex de, hl : ld (hl),b                                    ; ld (hl) = b = 0 

			ld 		a, '*' 	
			push 	ix 
			ld 		ix,.LABEL._filename 									; save hl to stack 
			ld 		hl,bufferfs+7											
			ld 		(hl),b 
			ld 		de,bufferfs+8
			ld 		bc,3 
			ldir 															; clear buffer 
			ld 		de,bufferfs

			ESXDOS : db F_SIZE	
			pop 	ix

			jr      nc,successfs
			jr      c,failopen
			; a = error code 
			jr      donefsizefs
	; data

	bufferfs:
			defs    12,0
	failopen: 
			ld      a,2
			out     ($fe),a
			jr      donefsizefs
	successfs:
			ld      a,3
			out     ($fe),a
			ld      hl,bufferfs+7
			ld      de,._bigsize
			ld      bc,4
			ldir 
			
	donefsizefs:
			
	end asm
end sub 

sub browserdir()

	asm 
		di 
		ld      (bdirsp+1),sp 
		nextreg $53,91
		ld      hl,$4000
		ld      de,$6000 
		ld      bc,2048
		ldir 
		nextreg $53,11
		nextreg TILEMAP_CONTROL_NR_6B,%00000000		; tilemap off 
	end asm 
	restoresys()
	cls 
	asm 


		ld sp,(.core.__CALL_BACK__)
		ei

	end asm 
	do 
	pause 4 
	loop until a = 0 

	'dot$="browse -t * -d -r -k -m -p "+chr(34)+"Choose a folder for saving downloads then press    space or Rename/Erase/maKedir/reMount"+chr(34)+" a$"
	dot$="browse -t * -d -r -k -m a$"
	ExecDot(dot$)
'	backupsysvar()
	asm 
	bdirsp:
		ld      sp,0
		nextreg $53,91
		ld      hl,$6000
		ld      de,$4000 
		ld      bc,2048
		ldir 
		nextreg $53,11
		NextReg TILEMAP_CONTROL_NR_6B,%11001001				; tilemap on & on top of ULA,  80x32 
	end asm 

end sub 

sub GetHTTPver()

	asm 
		di 
		nextreg MMU2_4000_NR_52,29 
	end asm 
	PeekMem($4002,0,ver$)
	asm 
		nextreg MMU2_4000_NR_52,10
	end asm 
	'AddText("Internal http version : "+ver$,6)
	LoadSD("c:/dot/http",$e000,128,0)
	PeekMem($e002,0,ver$)
	AddText("SD http version : "+ver$,6)

end sub 

sub fastcall PeekMem(address as uinteger,delimeter as ubyte,byref outstring as string)
	' assign a string from a memory block until delimeter 
	asm 
		push namespace peekmem 
		
		ex      de, hl 
		pop     hl 
		pop     af          ; delimeter 
		ex      (sp),hl         
		;' de string ram 
		;' hl source data 
		;' now copy to string temp
		push    hl 
		ex      de, hl 
		ld      de,.LABEL._stringtemp+2
		ld      bc,0 
	copyloop:
		cp      (hl)                 ; compare with a / delimeter 
		jr      z,endcopy            ; we matched 
		push    bc 
		ldi 
		pop     bc 
		inc     c
		jr      nz,copyloop          ; loop while c<>0
		dec     c 
	endcopy:
		ld      (.LABEL._stringtemp),bc 
		pop     hl 
		ld      de,.LABEL._stringtemp
		; de = string data 
		; hl = string 
		pop     namespace
		jp      .core.__STORE_STR
	end asm 

end sub 

SUB SNAPLOAD(snafilename as string)
	asm 
			;	; ; BREAK 
			LOCAL notfailed, failed
				ld a,(hl) 		; size of string 
				inc hl : inc hl : ld de,.LABEL._filename : ld b,0 : ld c,a : ldir 
				ld a,$FF : ld (de),a
				
		
				;ld hl,$0001  				; H=banktype (ZX=0, 1=MMC); L=reason (1=allocate)
				ld hl,.LABEL._filename
				exx
				ld c,7 						; RAM 7 required for most IDEDOS calls
				ld de,$00fd 				; IDE_SNAPLOAD ($00FD)
				rst $8:defb $94 			; M_P3DOS
				jp nc,failed
				ld a,e 
				jr notfailed
	failed:	
					out($fe),a

	notfailed:
		end asm 
end sub 

sub executebasic(command as string)
	asm 
   ; ; BREAK 
		push ix 
		; hl = start of string 
		; bc = length 
		ld 		c,(hl)
		inc 	hl
		ld 		b,(hl)
		inc 	hl 
		nextreg $56,28
		ld 		de,$c000 
		ldir 
		ld 		a,13 
		ld 		(de),a
		nextreg $56,0
		ld 		(outstack+1),sp 

		ld sp,(.core.__CALL_BACK__)

		ld 		b, 0                        ; IN: B=0, tokenise BASIC line
		ld 		c, 28                       ; IN: C=8K BANK containing buffer for untokenised BASIC line
		ld 		hl,0                        ; IN: HL=offset in BANK of buffer for untokenised line
		MP3DOS($01D8,0)               		; API IDE_TOKENIZE ($01D8, BANK 0) (see NextZXOS_and_esxDOS_APIs.pdf page 22)
		jr 		nc, Error                   ; If Carry flag unset, tokenize failed
		jr 		z, Error                    ; If Zero flag set, tokenize failed

		MP3DOS($01C0,0)              		; API IDE_BASIC ($01C0, BANK 0) (see NextZXOS_API.pdf page 18)
	Error:

	outstack:
		ld 		sp,0
		nextreg $56,0
		pop 	ix 
	end asm 
end sub

sub ExecDot(execfilename as string)
	ASM 
		; dont include the period eg "nexload myfile.nex" 
		; string pointer in hl 
		PROC 
		LOCAL exedotfailed, execdotdone, exeoldsp
		
		; ld 		(exeoldsp+1),sp 					; store sp for sfc below 
		; ld		sp,stackbuffer						; try saving stack manually 
		; ld 		sp,(.core.__CALL_BACK__)

		push 	ix
		push 	bc
		push 	de 									; for zxb saftey 
		; push 	hl 

		ld 		c,(hl) 								; hl points to string size 2 bytes 
		inc 	hl									; our max is 240ish bytes
		inc 	hl 
		ld 		de,.LABEL._filename 				; the destination for copy of string 
		ld 		b,0
		ldir 

		ld 		a,$0d								; EOL maker 
		ld 		(de),a								; ensure line finishes with EOL marker 

		ld 		ix,.LABEL._filename					; set ix to command string
		push 	ix
		pop 	hl 									; incase we're in dotland

		rst $8 : DB $8f 							;  M_EXECCMD ($8f)  - execute dotcommand 

		jp 		execdotdone

	exedotfailed:	
		; esxdos error in a 
		out		($fe),a										; handle the error however you want 

	execdotdone:

		; pop		hl 
		pop 	de
		pop 	bc
		pop 	ix

	exeoldsp:

		; ld		sp,0 								; sfc from above 
		; di         
		ENDP		
	end asm 
end sub 

Sub fastcall SplitString(source as uinteger, needle as ubyte, poision as ubyte) 

	asm 
	start2:
			; ; BREAK 
			exx : pop de : exx                          ; store return address 
			pop     af                                      ; a = neeedle off stack 
			ld      (needle),a                               ; store value at (needle)
			pop     af                                      ; position off stack 
			ld      (source),hl                              ; sotre hl into source 
			ld      de,needle                                ; point de to needle, hl = source, a position 
			push    ix : push bc 

			call    getstringsplit

			pop bc : pop ix 				
			exx : push de : exx                         ; restore ret address 

			ret                                         ; return 

getstringsplit:
			; hl = source 
			; de = needle 
			; a = index to get 
					; out hl = point to string or zero if not found
			
			ld      (source),hl									; save index 
			ld      hl,0
			ld      (stringtemp),hl
			call    countdelimters                             ; 
			ld      ix,currentindex                              ; point ix to index table 
			ld      hl,(source)                                    ; source string 
	
			ld      (indextoget),a                               ; save index to get 
			or      a : jr z,getfirstindex                       
	
	subloop:
			ld      de,needle                                    ; point to needle 
			ld      a,(de)                                       ; get needle
			ld      bc,0
			cpir 
			jr      z,foundneedle
			ret 
	
	foundneedle:
			; hl = location
			push    hl                                         ; save hl on stack 
			ld      b,a                                          ; save needle in b 
			inc     (ix+0)                                      ; inc currentindex 
			ld      a,(indextoget)                               ; get the index we want to look for
			cp      (ix+0)                                       ; does it match what we're on?
			jr      z,wefoundourindex                            ; found our index 
			pop     hl                                          ; pop hl from stack
			jr      subloop                                      ; loop around 
	
	getfirstindex:
			; used when index is 0 
			push    hl 
			ld      a,(needle) : ld b,a : ld c,$ff               ; max  size of string out = $ff
	
	wefoundourindex:
			; hl = start of string slice 
			ld      de,stringtemp+2                                ; tempstring save two bytes for length of string

	wefoundourindexloop:
			ld      a,(hl)                                       ; 
			or      a : jr z,copyends                            ; is this next char zero? 
			cp      b : jr z,copyends                            ; or the needle?
			ldi                                             ; no then copy to tempstring
			jr      wefoundourindexloop                          ; and keep looping 
	
	copyends:
			ex      de,hl                                        ; swap de / hl 
			ld      (hl), 0                                      ; zero terminate temp string
			xor     a : ld (currentindex),a                     ; reset current index for next run 
			pop     hl                                          ; pop hl off stack 
			ld      hl,stringtemp+2                                ; point to start of tempstring 
			ld      bc,0                                          ; b as length 

	genlenthtloop:
			ld      a,(hl) : or a : jr z,donelength : inc c : ld a,c : or a : jr z,donelength : inc hl : jr genlenthtloop 

	donelength:
			ld      hl,stringtemp : ld a,c : ld (hl),a : inc hl : ld a,b : ld (hl),a 
			ret                                             ; done ret
	
	countdelimters
			ld      c,a                                          ; save index count 
			ld      hl,totalindex
			ld      (hl),0
			ld      de,(source)
			ld      hl,needle
			ld      b,(hl)                                       ; pop needle into b 
	
	countdelimtersloop: 
			ld a,(de) : or a : jp z,indexcountdone          ; retrun if zero found
			cp b : jr z,increasedelimetercount        
			inc de 
			jr countdelimtersloop
	
	indexcountdone: 
			ld      a,(totalindex)
			cp      c
			jr      c,strfailed 
			ld      a,c
			ret  
	
	strfailed:
			pop     hl
			ld      hl,0
			ld      (stringtemp),hl
			ret 
	
	increasedelimetercount:
			ld      hl,totalindex
			inc     (hl)
			inc     de 
			jr      countdelimtersloop
	
	totalindex:
			db      0 
	
	currentindex:
			db      0     
	
	indextoget:
			db      0 

	source:
			dw      0000
	needle:
			db      "^"
			db      0 
	
	end asm 

end sub 

stringtemp:
	asm     
	stringtemp:
			ds 255,0
	end asm 


' sub SaveHTTP()

' 	asm
' 		di
' 		nextreg $52,24
' 	end asm 
	
' 	SaveSD("c:/dot/http",$4000,8192)
' 	asm
' 		nextreg $52,10
' 	end asm 

' 	file$="c:/dot/http"
' 	bigsize = 0 
' 	GetFileSize() 
	
' 	if bigsize=0
' 		AddText("Failed, please manually copy httpa to c:/dot/http",0)
' 		pause 0 
' 	else 
' 		AddText("c:/dot/http saved!",11)
' 	endif 

' end sub 



' end sub 
sub TextBlock(txx as ubyte, tyy as ubyte, helptextin as string, col as ubyte)

	asm 
		; cant be fast call due to bug in freeing string 
		push namespace textblock 
		;BREAK 
		add     a,a
		ld      (xpos+1),a 					; save the xpos 
		ld      a,(ix+7)
		and     31 							; line 32 is max line 
		ld      e,a 						; save in e 
		ld      hl,$4400 					; point hl to start of textmap area 
		ld      d,160						; text map is 160 bytes wide (tile + attribute * 80)
		mul     d,e  						; multiply this with the ypos 
		add     hl,de 						; add to start of textmap 
	xpos:
		ld      a,0							; xpos set with smc 
		add     hl,a 						; add to hl 
		ex      de,hl 						; swap hl into de 
		ld      h,(ix+9)					; get string address off ix 
		ld      l,(ix+8)
		ld      b,(hl)						; save string len in b
		add     hl,2 
		ld      a,(ix+11) 					; get colour
		ld      (col+1),a 					; save with smc 
	lineloop:
		push    bc 							; save loop size 
		ldi 								; copy hl to de then inc both  
	col:
		ld      a,0								; colour set with smc 
		and     %01111111						; and 6 bits 
		rlca								; rotate left 
		ld      (de),a 							; save in attribute location 
		inc     de 								; inc de
		pop     bc								; get back string len 
		djnz    lineloop 						; repeat while b<>0
	done: 
		pop     namespace
	
	end asm 

end sub 

' sub TextBlock(txx as ubyte, tyy as ubyte,helptextin$,col as ubyte)
' 	xx=txx : yy= tyy 
' 	if len helptextin$>0
' 	for x=0 to (len helptextin$)-1
' 		char=code helptextin$(x)	
' 		updatemap(xx,yy,char,col)
		
' 		'	if yy>=32
' 		'		asm 
' 		'			ld bc,$006b : ld a,$cf : out (c),a : ld a,$87 : out (c),a
' 		'		end asm 
' 		'		yy=screenlines-1
' 		'	endif 
' 		xx=xx+1 : if xx = 80 : yy = yy + 1 : xx = 0 : endif 
' 	next 
' 	endif 
' end sub 

sub fastcall PeekString2(address as uinteger,byref outstring as string)
	asm  
		ex      de, hl 
		pop     hl 
		ex      (sp), hl
		jp      .core.__STORE_STR 
	end asm 
end sub


sub fastcall PeekMemLen(address as uinteger,length as uinteger,byref outstring as string)
	' assign a string from a memory block with a set length 
	asm 

		ex      de, hl 
		pop     hl 
		pop     bc
		ex      (sp),hl         
		;' de string ram 
		;' hl source data 
		;' now copy to string temp
		
		push    hl 
		ex      de, hl 
		ld      (stringtemp),bc 
		ld      de,stringtemp+2
		ldir 

		pop     hl 
		ld      de,stringtemp
		; de = string data 
		; hl = string 
		jp      .core.__STORE_STR

	end asm 

end sub 

sub changedir(dir as string)
 	asm 
		; BREAK 
		f_esxdos					equ $08
		m_getsetdrv 			    equ $89
		f_opendir                   equ $a3 ;(163) open directory for reading 
		f_readdir                   equ $a4 ;(164) read directory entry 
		f_rewinddir                 equ $a7 ; (167) Rewind the dir 
		f_getcwd		            equ $a8 ; (167) get current working directory 
		f_close						equ $9b
		f_changecwd                 equ $a9

		push ix                             ; save IX 
		ld      c,(hl) :    inc hl          ; gets string from stack
		ld      b,(hl) :    inc hl 
		ld      de,.LABEL._filename     
		ldir                                ; copy into buffer 
		xor     a  
		ld      (de),a                      ; EOL terminator 
		ld      (._tempbyte),a 
		ld      a,'*'
		rst     f_esxdos : db m_getsetdrv	
		and		%111		; only want bits 2 - 0 should be 0 if no error
		jr      nc,chdirsuccess 
	   	ld      (._tempbyte),a 

chdirsuccess:

		ld      (handle),a
		ld      ix,.LABEL._filename
		rst     f_esxdos : db f_changecwd	
		
		ld      (._tempbyte),a 
		ld      a,(handle) 
		rst     f_esxdos : db f_close

		pop     ix 
 end asm 
		
end sub 

Sub GetCWD()

	asm
		PROC
		LOCAL  nsetdrive,successfs,doneopendir,failopen
		nsetdrive: 
			;; BREAK
			push ix
			ld hl,.LABEL._filename : ld (hl),0 : ld de,.LABEL._filename+1 : ld bc,128 : ldir				; clear filename buffer 
			ld a,'*'
			ld b,0
			ld ix,.LABEL._filename	
			ESXDOS : db $a8												; open dir  
			jr c,failopen												; failed to open 
			jr nc,successfs												; success 
			jr doneopendir
		failopen: 
			ld a,255
			jr doneopendir

		successfs:
		 	ld de,stringtemp+2										; point de to temp area 
			ld hl,.LABEL._filename									; hl to source 
		BREAK 
		fscopyloop;
			ld a,(hl) : or a : jr z,startgenloopfs : ldi : jr fscopyloop ; if (hl)<>0 copy to (de)

		startgenloopfs:
			ld bc,0 : xor a : ld (de),a
			ld hl,stringtemp+2 							; set hl to temp string start 
		genloopfs:													; count lengnth 
			ld a,(hl) : or a : jr z,donelengthfs : inc c : ld a,c : or a : jr z,donelengthfs : inc hl : jr genloopfs

		donelengthfs:												; store length 
			ld hl,stringtemp : ld a,c : ld (hl),a : inc hl : ld a,b : ld (hl),a 

		doneopendir:
			pop ix
		ENDP 	
		
	end asm
	PeekString2(@stringtemp,path$)											'; set path$ to cwd 
end sub 

sub fastcall updatemap(ux as ubyte, uy as ubyte, uv as ubyte, ucol as ubyte)
	asm 
		 
		exx : pop hl : exx 
		ld 		hl,$4400 : add a,a : ADD_HL_A		; add x * 2 because map is (char,attrib) x 80 
		; hl = $6000+x
		pop 	de : ld a,e : ld e,160 : MUL_DE		; mul 160 because map is 2 x 80 
		add 	hl,de : pop af						; get char to print 
		ld 		(hl),a : inc hl : 	pop af			; get colour 
		and 	%01111111
		rlca	
		ld 		(hl),a
outme:
		exx : push hl : exx 
		end asm 	
end sub   


sub cleartilemap()
	asm 
		ld 		hl,$4400
		ld 		de,$4401
		ld 		bc,2560*2
		ld 		(hl),0
		ldir 
	end asm 
end sub 


sub clearsection()
	asm 
		ld 		hl,$4400
		ld 		de,$4401
		ld 		bc,2879
		ld 		(hl),0
		ldir 
	end asm 
end sub 


sub colourrow(colour as ubyte)
	
		asm 
	;	; BREAK 
		push 	af 
		ld 		hl,$4400 
		ld 		a,(._rowyy)
		ld 		d,a
		ld 		e,160
		mul 	d,e 
		add 	hl,de				; start of row
		pop af 						; get colour
		and 	%01111111
		ld 		b,80
rowloop:		
		inc 	hl 
		ld 		a,(hl)
		xor 	32         			; adds to the colour 
		ld 		(hl),a 
		inc 	hl 
		djnz 	rowloop
		
		end asm 	

end sub


sub colourrowdown(colour as ubyte)
	
		asm 
	;	; BREAK 
		PROC 
		LOCAL rowloop, resetlp

		ld 		hl,$4400             ; start of tile data 
		ld 		a,(._rowyy)
		ld 		d,a
		ld 		e,160
		mul		d, e 
		add 	hl,de				; start of row
		push 	hl             		; save this address 
		; here we are at the start of the line 

		add 	hl,$ff60        	; sub 1 line 160 chrs 
		ld 		b,80
resetlp: 
		inc 	hl 
		ld 		a,(hl)
		xor 	32 
		ld 		(hl),a
		inc 	hl 
		djnz resetlp

		pop 	hl 
		and 	%01111111

		ld 		b,80
	  
rowloop:		
		inc 	hl 
		ld 		a,(hl)
		add 	a,32            	; adds to the colour 
		ld 		(hl),a 
		inc 	hl 
		djnz 	rowloop
		ENDP 
		end asm 	

end sub

sub colourrowup(colour as ubyte)
	
		asm 
	;	; BREAK 
		PROC 
		LOCAL rowloop, resetlp
		ld 		hl,$4400             ; start of tile data 
		ld 		a,(._rowyy)
		ld 		d,a
		ld 		e,160
		mul		d,e  				; get offset 
		add 	hl,de				; start of row
		push 	hl             		; save this address 
		; here we are at the start of the line 

		add 	hl,160       		; sub 1 line 160 chrs 
		ld 		b,80
resetlp: 
		inc 	hl 
		ld 		a,(hl)
		sub 	32
		ld 		(hl),a
		inc 	hl 
		djnz 	resetlp

		pop 	hl 
		and 	%01111111
		ld 		b,80
		
rowloop:		
		inc 	hl 
		ld 		a,(hl)
		add 	a,32            ; adds to the colour 
		ld 		(hl),a 
		inc 	hl 
		djnz 	rowloop
		ENDP 
		end asm 	

end sub

sub backupsysvar() 

	asm 
		di 
		nextreg MMU7_E000_NR_57,90
		ld 		hl,$5C00
		ld 		de,$e000 
		ld 		bc,256
		ldir 
		
	end asm 
'	SaveSD("sysvar.bin",$e000,256)
	asm
		nextreg MMU7_E000_NR_57,1
	end asm

end sub 

sub restoresys()

	asm 
	di 
		nextreg MMU7_E000_NR_57,90
		ld 		de,$5C00
		ld 		hl,$e000 
		ld 		bc,256
		ldir 
		nextreg MMU7_E000_NR_57,1
	end asm 	

end sub

sub SaveCFG()
	asm 
		nextreg $52,25 						; page in temp bank
		ld 		hl,$4000
		ld 		(hl),0
		ld 		de,$4001
		ld 		bc,$210
		ldir 
		ld 		hl,(._path)						; point to start of path string 
		ld 		c,(hl) : inc hl 					; get bc of string size 
		ld 		b,(hl) : dec hl 
		add 	bc,2							; add 2 for size + string 
		ld 		de,$4000 
		ldir 								; copy to $4000
		ld 		hl,$4100							; move to $4200 
		ld 		a,(._baud)
		ld 		(hl),a 
	end asm 
	SaveSD("c:/sys/zxdb.cfg",$4000,$210)
	asm 
		nextreg $52,10
	end asm 
end sub 

sub LoadCFG()
	asm 
		nextreg $57,25 						; page in temp bank
		ld hl,$e000 : ld (hl),0 : ld de,$e001 : ld bc,$210 : ldir 
	end asm 

	LoadSD("c:/sys/zxdb.cfg",$e000,$210,0)
	PeekString2($e000,path$)
	baud = peek($e100) 		
	asm 
		nextreg $57,1
	end asm 
	if left(path$,3)="C:/"
		'path$=path$( to LEN(path$)-2)
		changedir(path$)
	else 
		changedir("downloads")
		GetCWD()
		SaveCFG()
	endif 
end sub 

Sub TextScreen()
	dim l, c, ol as ubyte 
	read l,t$,c 
	while l<>254 
		if l=-1 : ol=ol+1 : l = ol : endif 
		TextBlock(0,l,t$,c)
		read l,t$,c 
	wend 
end sub 

' border tempstack(0)

infoscreen:
	DATA 3,"Next ZXDB-dl search - em00k 19/05/21 "+ver$,6
	DATA 5,"Thanks to Remy Sharp for his brilliant .http",3
	DATA 6,"https://github.com/remy/next-http",4
	DATA 7,"along with his Next ZXDB API proxy",5
	DATA 9,"D Xalior Rimron-Soutter for his awesome backend support",3
	DATA 10,"scripting and hosting his NextBestNetwork",4
	DATA 11,"https://www.nextbestnetwork.com/wos/",5
	DATA 13,"Commands: ",6
	DATA 14,"#cd [path]  - change path, #q - quit to basic, #s[0-6] - Set baud",5
	DATA 15,"#http - save http to c:/dot, #ver show http version",5
	' DATA 14,"#cd [path]  - change path, #q - quit to basic",5
	Data 254,"",0

savedata:
	asm 
	savedata:
		ds 256,0
	end asm 


asm 
handle:
		db 0 
end asm 


fontzx7:
asm 
	incbin ".\data\topan.fnt.zx7"
	defs 6,0
end asm 

palettezx7:
asm 
	incbin ".\data\mm.pal.zx7"
	defs 6,0
end asm   
 