"""
#############
@JPCS_12/2022
#############
called by runUnpacker.py
"""

import sys
import binascii
import itertools
import pandas as pd
from textwrap   import wrap
from functools  import partial
from contextlib import ExitStack

n = 8    #number of words per line (8 words; 1 word = 8 hex = 4 bytes)  n -> used by unpack()
m = 4    #number of bytes per word (4 bytes; 1 byte = 2 hex = 8 bits ); m -> used by unpack() and convertToData()
HEXlettersForFpgaName      = 4                              #usually the number of hex letters is always 4
HEXlettersForNumberOfWords = m*2 - HEXlettersForFpgaName    #m*2 -> number of bytes per word *2 = number of hex letters

def unpack(InputPath, OutputPath, DebugMode, NumberOfEvents=None):
    with open(InputPath, 'rb') as f_IN, open(OutputPath, 'w') as f_OUT:
        firstLine         = 1    #write run header once
        newEvent          = 0    #newEvent=1    -> event header must be written
        newSubEvent       = 0    #newSubEvent=1 -> the size of the next sub event will be provided (new sub event = data from another FPGA in the system)
        CountedwordsEvent = 0
        CountedEvents     = 0    #counter of number of events (exit after X events)
        wordsOfNewEvent   = 0    #number of words of each event (provided in the event header (=number of bytes / m)); includes the 'aaaaaaaa' words
        L_data = []    #EACH FPGA (SUB EVENT) WILL HAVE ITS L_data WITH ALL THE RESPECTIVE WORDS (FROM SIZE TO '00015555', '00000001'): ['00000060', '00020011', '0000c001', ... '00015555', '00000001']
        #for block in iter(lambda: f_IN.read(32), b''):
        for block in iter(partial(f_IN.read, 32), b''):    #maybe a bit faster than with lambda; https://docs.python.org/3/library/functions.html#iter
            HexLine = binascii.hexlify(block)   #HexLine -> <class 'bytes'> b'20000000010003000200010000000000180a7a002b0e1000730cf91b00000000'
            #print(HexLine)
            #f_OUT.write("b'XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX'\n")
            #f_OUT.write(f"{HexLine}\n")    #b'XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX'
            #HexLine = codecs.encode(block, 'hex')    #must use: import codecs;    #maybe a bit slower than with binascii.hexlify
            L_bytes = wrap(HexLine.decode("utf-8") , 2)    #['20', '00', '00', '00', '01', '00', '03', '00', ..., '00', '00', '00', '00']
            L_bytes_ordered = [(L_bytes[i+3],L_bytes[i+2],L_bytes[i+1],L_bytes[i+0])  for i in range(0, len(L_bytes), 4)]
            L_bytes_ordered = [''.join(w) for w in L_bytes_ordered]
            #print(L_bytes_ordered)
            #f_OUT.write(f"{L_bytes_ordered}\n")
            L_bytes_normal  = [HexLine[i:i+n].decode("utf-8")  for i in range(0, len(HexLine), n)]    #em string (definir antes n=8)
            #L_bytes_normal = [HexLine[i:i+n]  for i in range(0, len(HexLine), n)]    #em bytes
            #print(L_bytes_normal)
            #f_OUT.write(f"{L_bytes_normal}\n")
            if firstLine == 1:    #FILE HEADER (ONCE PER FILE)
                print(f"⮕  {InputPath.split('/')[-1]}")
                Bytes = int(L_bytes_ordered[0],16)
                if DebugMode:
                    f_OUT.write("########  FILE HEADER  #########\n")
                    f_OUT.write(f"{L_bytes_ordered[0]} \t->\t size: {Bytes} bytes ({Bytes//4} words)\n")    #{Bytes//4} instead of {Bytes/4:.0f}
                    f_OUT.write(f"{L_bytes_ordered[1]} \t->\t decoding\n")
                    f_OUT.write(f"{L_bytes_ordered[2]} \t->\t id\n"      )
                    f_OUT.write(f"{L_bytes_ordered[3]} \t->\t seqNr\n"   )
                    f_OUT.write(f"{L_bytes_ordered[4]} \t->\t date: {int(L_bytes_ordered[4][6:8],16)}-{int(L_bytes_ordered[4][4:6],16)}-{int(L_bytes_ordered[4][2:4],16)} - {int(L_bytes_ordered[4][0:2],16)}\n")
                    f_OUT.write(f"{L_bytes_ordered[5]} \t->\t time: {int(L_bytes_ordered[5][2:4],16)}h {int(L_bytes_ordered[5][4:6],16)}m {int(L_bytes_ordered[5][6:8],16)}s - {int(L_bytes_ordered[5][0:2],16)}\n")
                    f_OUT.write(f"{L_bytes_ordered[6]} \t->\t runNr\n"   )
                    f_OUT.write(f"{L_bytes_ordered[7]} \t->\t\n"         )
                firstLine = 0
            elif firstLine == 0 or newEvent == 1:    #EVENT HEADER (ONCE PER EVENT)
                firstLine = None    #can't enter again in this elif branch because of firstLine
                if CountedEvents % 1000 == 0:    #to know if the script is running as expect; e.g. 10000
                    print('unpacked events: ', CountedEvents)
                if CountedEvents  == NumberOfEvents:    #unpack only the provided NumberOfEvents
                    print('script stopped after the provided number of events:', NumberOfEvents)
                    break; #break instead of sys.exit() -> in case InputPath is a folder and several files must be unpacked with a fixed value of NumberOfEvents
                CountedEvents += 1
                if L_data:    #L_data NOT EMPTY; L_data was already reordered in the previous loop, no need to do it here
                    L_temp = L_data + L_bytes_ordered[0:8-len(L_data)]  #L_temp has now the 8 words of a 'normal' event header (does the same as L_bytes_ordered)
                    L_data = L_bytes_normal[8-len(L_data):]            #L_data has now only words for the starting sub event
                    bytesOfEvent      = int(L_temp[0],16)
                    wordsOfNewEvent   = bytesOfEvent//m
                    CountedwordsEvent = len(L_temp) + len(L_data)    #CountedwordsEvent reinitialized
                    if DebugMode:
                        f_OUT.write("########  EVENT HEADER  #######\n")
                        f_OUT.write(f"{L_temp[0]} \t->\t size: {bytesOfEvent} bytes ({wordsOfNewEvent:.0f} words)\n")
                        f_OUT.write(f"{L_temp[1]} \t->\t decoding\n"            )
                        f_OUT.write(f"{L_temp[2]} \t->\t id\n"                  )
                    f_OUT.write(    f"{L_temp[3]} \t->\t seqNr (EVENT NUMBER)\n")
                    if DebugMode:
                        f_OUT.write(f"{L_temp[4]} \t->\t date: {int(L_temp[4][6:8],16)}-{int(L_temp[4][4:6],16)}-{int(L_temp[4][2:4],16)} - {int(L_temp[4][0:2],16)}\n"   )
                        f_OUT.write(f"{L_temp[5]} \t->\t time: {int(L_temp[5][2:4],16)}h {int(L_temp[5][4:6],16)}m {int(L_temp[5][6:8],16)}s - {int(L_temp[5][0:2],16)}\n")
                        f_OUT.write(f"{L_temp[6]} \t->\t runNr\n"               )
                        f_OUT.write(f"{L_temp[7]} \t->\t\n"                     )
                    #print('Event: ', L_temp[3])
                else:    #'NORMAL' EVENT HEADER
                    bytesOfEvent      = int(L_bytes_ordered[0],16)
                    wordsOfNewEvent   = bytesOfEvent//m
                    CountedwordsEvent = len(L_bytes_ordered)    #CountedwordsEvent reinitialized
                    if DebugMode:
                        f_OUT.write("########  EVENT HEADER  #######\n")
                        f_OUT.write(f"{L_bytes_ordered[0]} \t->\t size: {bytesOfEvent} bytes ({wordsOfNewEvent:.0f} words)\n")
                        f_OUT.write(f"{L_bytes_ordered[1]} \t->\t decoding\n"            )
                        f_OUT.write(f"{L_bytes_ordered[2]} \t->\t id\n"                  )
                    f_OUT.write(    f"{L_bytes_ordered[3]} \t->\t seqNr (EVENT NUMBER)\n")
                    if DebugMode:
                        f_OUT.write(f"{L_bytes_ordered[4]} \t->\t date: {int(L_bytes_ordered[4][6:8],16)}-{int(L_bytes_ordered[4][4:6],16)}-{int(L_bytes_ordered[4][2:4],16)} - {int(L_bytes_ordered[4][0:2],16)}\n")
                        f_OUT.write(f"{L_bytes_ordered[5]} \t->\t time: {int(L_bytes_ordered[5][2:4],16)}h {int(L_bytes_ordered[5][4:6],16)}m {int(L_bytes_ordered[5][6:8],16)}s - {int(L_bytes_ordered[5][0:2],16)}\n")
                        f_OUT.write(f"{L_bytes_ordered[6]} \t->\t runNr\n"               )
                        f_OUT.write(f"{L_bytes_ordered[7]} \t->\t\n"                     )
                    #print('Event: ', L_bytes_ordered[3])
                if  wordsOfNewEvent != 8:    #if wordsOfNewEvent=8 -> it is an event header without sub events!! i.e. another event header will follow, therefore keep newEvent=1
                    newEvent    = 0
                    newSubEvent = 1    #check size of new sub event...
                else:    #an event header after another one -> since the next loop will not go to 'if newSubEvent == 1:', L_data will not be reordered; it must be done here
                    L_data = L_bytes_ordered[8-len(L_data):]
            else:    #ALL THE OTHER LINES (not a file header (first line) nor an event header (second line or newEvent set to 1)
                if newSubEvent == 1:    #NEW SUB EVENT
                    L_data.extend(L_bytes_normal)
                    if 'aaaaaaaa' in L_data:    #'aaaaaaaa' -> padding word to make the next subsubevent aligned with a 64 bit boundary. (mantem o size word sempre numa posição par)
                        L_data.remove('aaaaaaaa')    #the length of L_data will be lower by one word
                        #print("'aaaaaaaa' found in new sub event!")
                    bytesOfSubEvent = int(L_data[0],16)
                    wordsOfSubEvent = bytesOfSubEvent//m    #wordsOfSubEvent DOES NOT includes the 'aaaaaaaa' words (while wordsOfNewEvent includes them)
                    if DebugMode:
                        f_OUT.write("########  SUB EVENT  #######\n")
                        f_OUT.write(f"{L_data[0]} \t->\t size: {bytesOfSubEvent} bytes ({wordsOfSubEvent:.0f} words)\n")
                        f_OUT.write(f"{L_data[1][0:-2] + '0' + L_data[1][-1]} \t->\t decoding\n"         )    #STRANGE, like this?
                    f_OUT.write(    f"{L_data[2]} \t->\t id (FPGA)\n"                                    )
                    if DebugMode:
                        f_OUT.write(f"{L_data[3]} \t->\t trigNr\n"                                       )
                        f_OUT.write(f"{int(L_data[1][-2]):8d} \t->\t trigTypeTRB3\n"                     )
                        f_OUT.write(f"{wordsOfSubEvent:8.0f} \t->\t total number of words of sub event\n")
                    newSubEvent = 0
                    #f_OUT.write(f"{L_data}\n")
                else:    #MIDDLE or end OF SUB EVENT
                    L_data.extend(L_bytes_normal)
                    if 'aaaaaaaa' in L_data:    #'aaaaaaaa' -> padding word to make the next subsubevent aligned with a 64 bit boundary. (mantem o size word sempre numa posição par)
                        L_data.remove('aaaaaaaa')    #BUT the length of L_data will be lower by one word
                        #print("'aaaaaaaa' found in middle/end of event!")
                    L_indexes = [index for index, value in enumerate(L_data) if value == '00015555']
                    if L_indexes:
                        if len(L_indexes) > 1:
                            print("'00015555' found at indexes: ", L_indexes)
                        if DebugMode:
                            f_OUT.write(f"'00015555' found in L_data at indexes: {L_indexes}\n")
                        indexMarker = L_indexes[-1] +2    #take the last index in the list; +1 -> L start at 0; +1 -> to inc one word after 00015555
                        L_data_subEvent = L_data[:indexMarker]
                        if wordsOfSubEvent == len(L_data_subEvent):    #ok, write data and go to next subevent
                            L_data = L_data[indexMarker:]
                            if DebugMode:
                                f_OUT.write(f"{len(L_data_subEvent):8d} \t->\t DATA words found (as expected)\n")
                                f_OUT.write(f"data of sub event:\n{L_data_subEvent}\n")
                                f_OUT.write(f"data for next sub event:\n{L_data}\n"   )
                            else:
                                f_OUT.write(f"{L_data_subEvent}\n")
                            newSubEvent = 1
                        elif wordsOfSubEvent > len(L_data_subEvent):    #not ok, maybe '00015555' is simply data, try again
                            if DebugMode:
                                f_OUT.write(f"{len(L_data_subEvent):8d} \t->\t DATA words found (below the expected {wordsOfSubEvent:.0f} words)\n")
                        else:    #can't happen
                            print("something wrong: words of sub event higher than expected\nAborting...")
                            sys.exit()
                CountedwordsEvent = CountedwordsEvent + len(L_bytes_normal)    # + len(L_bytes_normal)  OR   +n ...
                if CountedwordsEvent - len(L_data) == wordsOfNewEvent:    #ALL THE WORDS OF THE EVENT WERE COUNTED (L_data might already have some data of the next event)
                    L_data = L_bytes_ordered[8-len(L_data):]    #L_data can be reordered right here
                    newEvent = 1
                elif CountedwordsEvent - len(L_data) > wordsOfNewEvent:
                    print('something wrong: words of event different than expected\nAborting...')
                    sys.exit()
            #f_OUT.write(f"({CountedwordsEvent:4d}, {wordsOfNewEvent-CountedwordsEvent:4.0f}, {wordsOfNewEvent:4.0f}) \t (words of the event up to this line, words until the end of event, total number of words of the event) \n")
        print('unpacked events: ', CountedEvents -1)    #-1: the hld file ends always with an EMPTY event header, e.g.: '00000028 	->	 seqNr (EVENT NUMBER)' with the last line '0000c001 	->	 id (FPGA)'


def calibrateFineTime(InputPath, L_OutputFTimePath, CalibFTimePath, L_FPGAs, NumberOfEvents, L_OutputFTimeFpga):
    #InputPath                /home/jpcs/Desktop/RPCs/unpackerTRB3/dabc23013170059.txt
    #CalibFTimePath           ./calibrationFTime.tdc
    #NumberOfEvents           None
    #L_OutputFTimePath        ['./dabc23013170059_a001.fTime', './dabc23013170059_a002.fTime', './dabc23013170059_a003.fTime']
    #L_OutputFTimeFpga        ['a001', 'a002', 'a003']    #TDCs only
    #L_FPGAs                  [('central_CTS', ['c001'], ['a001', 'a002', 'a003', 'a004']), ('tdc', ['a001', 'a002', 'a003']), ('adc', ['a004'])]
    #L_onlyFPGAs              ['c001', 'a001', 'a002', 'a003', 'a004']    #all item[1] of L_FPGAs
    #L_peripheralFPGAs        ['a001', 'a002', 'a003', 'a004']            #peripheral fpgas of a TRB3 (a central one was found); the central fpga might have TDC chs
    #L_PeriphAndCentralFPGAs  ['a001', 'a002', 'a003', 'a004', 'c001']    #central fpga at the end; while L_onlyFPGAs has the central at the beginning
    #L_L_wordsPerFPGA         [L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4, L_words_central_CTS]
    with ExitStack() as stack:    #create the dabcXXXX_fpga.fTime files using dabcXXXX.txt as input
        f_IN          =  stack.enter_context(open(InputPath, 'r'))
        L_f_OUT       = [stack.enter_context(open(fname, 'w')) for fname in L_OutputFTimePath]
        L_onlyFPGAs   = [fpga for item in L_FPGAs for fpga in item[1]]    #e.g. ['c001', 'a001', 'a002', 'a003', 'a004']
        event         = 0
        fpgaFound     = 0
        CountedEvents = 0    #counter of number of events (exit after X events)
        for line in f_IN:
            if line[-21:-1] == 'seqNr (EVENT NUMBER)':
                event = int(line[0:8],16)
                if CountedEvents % 10000 == 0:    #to know if the script is running as expect; e.g. 10000, 20000...
                    print('calibrated events: ', CountedEvents)
                if CountedEvents  == NumberOfEvents:    #unpack only the provided NumberOfEvents
                    print('script stopped after the provided number of events:', NumberOfEvents)
                    break; #sys.exit()
                CountedEvents += 1
            elif fpgaFound == 1:
                if indexOfCurrentFPGA >= 0:    #<0 -> it is a central or adc fpga; >=0 normal index of L_OutputFTimeFpga (tdc fpga)
                    L_words = eval(line)
                    result = TDC(L_words, T_event_Path=(event, L_f_OUT[indexOfCurrentFPGA]))    #call TDC function; its return is not needed except if no TDC header is found
                    if result == 1:
                        print(f"No TDC header found in FPGA: {fpga} -> check the provided 'L_fpgas' in runUnpacker.py!\nAborting...")    #fpga variable provived in the previous loop in 'elif event:'
                        sys.exit()
                elif indexOfCurrentFPGA == -2:    #central_CTS fpga found; fpga lists available: L_OutputFTimeFpga, L_FPGAs, L_onlyFPGAs, L_peripheralFPGAs, L_PeriphAndCentralFPGAs
                    if any(FPga in L_OutputFTimeFpga for FPga in L_PeriphAndCentralFPGAs):    #don't proceed if there is no TDCs in L_PeriphAndCentralFPGAs
                        L_words = eval(line)    #includes data from the peripheral fpgas + the central (at the end of L_words)
                        ##############
                        ############## (alternative probably faster)
                        #ALTERNATIVE1: search indexes of all fpgas by name; without cross check with the provided number of words for each fpga
                        #L_temp = [word[HEXlettersForNumberOfWords:] for word in L_words]    #list with only the last 4 letters of each word
                        #try:
                        #    L_indexWordFPGAs = [L_temp.index(Fpga,3) for Fpga in L_PeriphAndCentralFPGAs]    #indexes of all fpgas; e.g. [4, 7, 10, 13, 974]; .index(Fpga,3) -> to skip the first 3+1 words of the header (otherwise the index of '0000c001' (of the central fpga in the header) will be provided)
                        #except ValueError as valErr:
                        #    print(f"{valErr} (of a central_CTS FPGA): {L_temp} -> check the provided FPGAs in runUnpacker.py!\nAborting...")
                        #    sys.exit()
                        #L_L_wordsPerFPGA = [L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]] for i in range(4)]    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]
                        #L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[-1]:-2])    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4, L_words_central_CTS]; -2 -> to remove ['00015555', '00000001']
                        ##############
                        ##############
                        #ALTERNATIVE2: search only the index of the 1st (peripheral) fpga by name; the other indexes are obtained via the provided number of words for each fpga



                        #L_indexWordFPGAs = [[word[HEXlettersForNumberOfWords:] for word in L_words].index(L_peripheralFPGAs[0])]    #list with only the index of the 1st periph fpga; e.g. [4]

                        #issue in this case (fpga = a001): ['00001ec0', '00020011', '0000c001', '0000a001', '0010a001',...
                        #force position of 1st fpga in position 4
                        L_indexWordFPGAs = [4]



                        #L_wordsHeader    = L_words[0:L_indexWordFPGAs[0]]    #don't care; e.g. ['00000F9C', '00020011', '0000c001', '04601c1f']
                        L_L_wordsPerFPGA = []    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4, L_words_central_CTS]
                        for i in range(5):    #[0,1,2,3,4]
                            numberOfWords = int(L_words[L_indexWordFPGAs[i]][:HEXlettersForNumberOfWords], 16) +1    #+1 -> to include the 1st word of the fpga (e.g. '0002a001')
                            L_indexWordFPGAs.append(L_indexWordFPGAs[i] + numberOfWords)    #the last append will be the index of '00015555'; e.g. [4, 7, 10, 13, 974, 992]
                            L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]])
                        totalNumberOfWords   = int(L_words[0], 16) // m      #e.g. '00000f88' /4 = 3976/4 = 994 words for this event
                        countedNumberOfWords = L_indexWordFPGAs[-1] +1 +1    #+1 -> started to count at '0'; +1 -> to include the last word (after '00015555'): '00000001'
                        if totalNumberOfWords != countedNumberOfWords:
                            print(f'Number of words found (during CALIBRATION) in event {event}: {countedNumberOfWords} (for the central_CTS FPGA: {fpga}),',
                            f'while the expected is {totalNumberOfWords} (provided by the 1st word of the event)\naborting...')
                            #sys.exit()
                        ##############
                        ##############
                        for ind, FpGa in enumerate(L_PeriphAndCentralFPGAs):    #if any of the fpgas are tdcs calib them; index of L_PeriphAndCentralFPGAs = index of L_L_wordsPerFPGA
                            if FpGa in L_OutputFTimeFpga:
                                indexOfCurrentFPGA = L_OutputFTimeFpga.index(FpGa)    #indexOfCurrentFPGA changes from -2 to the correct index; index of L_OutputFTimeFpga = index of L_f_OUT
                                result = TDC(L_L_wordsPerFPGA[ind], T_event_Path=(event, L_f_OUT[indexOfCurrentFPGA]))    #call TDC function; its return is not needed except if no TDC header is found
                                if result == 1:
                                    print(f"No TDC header found in FPGA: {FpGa} (of the central_CTS FPGA: {fpga}) -> check the provided 'L_fpgas' in runUnpacker.py!\nAborting...")    #fpga variable provived in the previous loop in 'elif event:'
                elif indexOfCurrentFPGA == -3:    #central fpga found; since it is not a CTS, there is no words at the end of L_words regarding the central fpga
                    if any(FPga in L_OutputFTimeFpga for FPga in L_peripheralFPGAs):
                        L_words = eval(line)
                        ##############
                        ############## (alternative probably faster)
                        #ALTERNATIVE1: search indexes of all fpgas by name; without cross check with the provided number of words for each fpga
                        #L_temp = [word[HEXlettersForNumberOfWords:] for word in L_words]    #list with only the last 4 letters of each word
                        #try:
                        #    L_indexWordFPGAs = [L_temp.index(Fpga,3) for Fpga in L_peripheralFPGAs]    #e.g. [4, 9, 17, 24]
                        #except ValueError as valErr:
                        #    print(f"{valErr} (of a central FPGA): {L_temp} -> check the provided FPGAs in runUnpacker.py!\nAborting...")
                        #    sys.exit()
                        #L_L_wordsPerFPGA = [L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]] for i in range(3)]    #[L_words_periph1, L_words_periph2, L_words_periph3]
                        #L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[-1]:-2])    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]; -2 -> to remove ['00015555', '00000001']
                        ##############
                        ##############
                        #ALTERNATIVE2: search only the index of the 1st (peripheral) fpga by name; the other indexes are obtained via the provided number of words for each fpga
                        L_indexWordFPGAs = [[word[HEXlettersForNumberOfWords:] for word in L_words].index(L_peripheralFPGAs[0])]    #list with only the index of the 1st periph fpga; e.g. [4]
                        #L_wordsHeader    = L_words[0:L_indexWordFPGAs[0]]    #don't care; e.g. ['00000F9C', '00020011', '0000c001', '04601c1f']
                        L_L_wordsPerFPGA = []    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]
                        for i in range(4):    #[0,1,2,3]; one less than in case of 'central_CTS FPGA' because with a 'central FPGA' there are no words from the CTS after the 4 peripheral fpgas
                            numberOfWords = int(L_words[L_indexWordFPGAs[i]][:HEXlettersForNumberOfWords], 16) +1    #+1 -> to include the 1st word of the fpga (e.g. '0002a001')
                            L_indexWordFPGAs.append(L_indexWordFPGAs[i] + numberOfWords)    #the last append will be the index of '00015555'; e.g. [4, 9, 17, 24, 29]
                            L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]])
                        totalNumberOfWords   = int(L_words[0], 16) // m      #e.g. '00000f88' /4 = 3976/4 = 994 words for this event
                        countedNumberOfWords = L_indexWordFPGAs[-1] +1 +1    #+1 -> started to count at '0'; +1 -> to include the last word (after '00015555'): '00000001'
                        if totalNumberOfWords != countedNumberOfWords:
                            print(f'Number of words found (during CALIBRATION) in event {event}: {countedNumberOfWords} (for the central FPGA: {fpga}),',
                            f'while the expected is {totalNumberOfWords} (provided by the 1st word of the event)\naborting...')
                            sys.exit()
                        ##############
                        ##############
                        for ind, FpGa in enumerate(L_peripheralFPGAs):
                            if FpGa in L_OutputFTimeFpga:
                                indexOfCurrentFPGA = L_OutputFTimeFpga.index(FpGa)
                                result = TDC(L_L_wordsPerFPGA[ind], T_event_Path=(event, L_f_OUT[indexOfCurrentFPGA]))    #call TDC function; its return is not needed except if no TDC header is found
                                if result == 1:
                                    print(f"No TDC header found in FPGA: {FpGa} (of the central FPGA: {fpga}) -> check the provided 'L_fpgas' in runUnpacker.py!\nAborting...")    #fpga variable provived in the previous loop in 'elif event:'
                fpgaFound = 0
            elif event:
                fpga = line[:8].lstrip('0')
                if fpga in L_onlyFPGAs:              #to be sure the fpga was provided in L_FPGAs
                    if fpga in L_OutputFTimeFpga:    #it is a TDC fpga
                        indexOfCurrentFPGA = L_OutputFTimeFpga.index(fpga)
                    else:                            #it can be a: central, central_CTS (TRB3) or ADC
                        for item in L_FPGAs:         #check if it is a central or ADC
                            if fpga in item[1] and item[0] == 'central_CTS':    #item[0] -> 'central_CTS', item[1] -> ['c001']
                                L_peripheralFPGAs = item[2]                     #item[2] -> ['a001', 'a002', 'a003', 'a004']
                                L_PeriphAndCentralFPGAs = item[2] + item[1]     #['a001', 'a002', 'a003', 'a004', 'c001']    (central fpga at the end; while L_onlyFPGAs has the central at the end)
                                indexOfCurrentFPGA = -2    #it is a central_CTS FPGA, we have now its peripheral FPGAs (but still don't know if some of them are TDCs or not...)
                                break    #central_CTS FPGA found, exit to don't change the value of indexOfCurrentFPGA in the next iteration
                            elif fpga in item[1] and item[0] == 'central':    #item[0] -> 'central', item[1] -> ['c001']
                                L_peripheralFPGAs = item[2]                   #item[2] -> ['a001', 'a002', 'a003', 'a004']
                                indexOfCurrentFPGA = -3
                                break    #central FPGA found, exit to don't change the value of indexOfCurrentFPGA in the next iteration
                            else:
                                indexOfCurrentFPGA = -1
                    fpgaFound = 1
                else:
                    print(f"{fpga} not found in {L_onlyFPGAs} -> check the provided 'L_fpgas' in runUnpacker.py!\nAborting...")
                    sys.exit()
            else:
                print(f"something wrong with the file: {InputPath}\n('seqNr (EVENT NUMBER)' not found in the 1st line)\nAborting...")
                sys.exit()
        print('calibrated events: ', CountedEvents -1)    #-1: explained already for the unpacked events -> the hld file ends always with an EMPTY event header
    with open(CalibFTimePath, 'a') as f_FtimeOUT:    #create 'calibrationFTime.tdc', writting for each dabcXXXX_fpga.fTime and for each ch: [min, max, diff]; e.g. {0: [16, 494, 478], 1:...}
        for file in L_OutputFTimePath:
            df = pd.read_csv(file, sep='\s+', engine='c', header=None, names=['event', 'ch', 'edge', 'fTime'])
            chs_sorted = sorted(df.ch.unique())
            min_fTime = []
            max_fTime = []
            for ch in chs_sorted:
                temp_data = df['fTime'].loc[df['ch'] == ch]    #all the fine time value for a specific ch (don't care about the edge (rising or falling))
                min_fTime.append(temp_data.min())
                max_fTime.append(temp_data.max())
            dif_fTime = [max-min for min, max in zip(min_fTime, max_fTime)]
            Dic_fTime = {i:[j, k, l] for i, j, k, l in zip(chs_sorted, min_fTime, max_fTime, dif_fTime)}
            f_FtimeOUT.write(f"######## {file} #######\n")
            f_FtimeOUT.write(f"{Dic_fTime}\n")


def convertToData(InputPath, L_OutputPath, L_FPGAs, D_CalibFTime, NumberOfEvents, DebugMode):
    with ExitStack() as stack:    #https://stackoverflow.com/questions/4617034/how-can-i-open-multiple-files-using-with-open-in-python
        f_IN          =  stack.enter_context(open(InputPath, 'r'))
        L_f_OUT       = [stack.enter_context(open(fname, 'w')) for fname in L_OutputPath]    #L_f_OUT = [<'./dabc*_c001.central_CTS'>,<'./dabc*_a001.tdc'>,<'./dabc*_a002.tdc'>,<'./dabc*_a003.tdc'>,<'./dabc*_a004.adc'>]
        L_onlyFPGAs   = [fpga for item in L_FPGAs for fpga in item[1]]    #[('central_CTS', ['c001'], ['a001', 'a002', 'a003', 'a004']), ('tdc', ['a001', 'a002', 'a003']), ('adc', ['a004'])] -> ['c001', 'a001', 'a002', 'a003', 'a004']
        event         = 0
        fpgaFound     = 0
        CountedEvents = 0    #counter of number of events (exit after X events)
        D_eventsLessWordsThanExpected = {}
        for line in f_IN:
            if line[-21:-1] == 'seqNr (EVENT NUMBER)':
                event = int(line[0:8],16)    #event passa a ser dif de 0 -> na proxima linha, o for loop entra no 'elif event'
                if CountedEvents % 10000 == 0:    #to know if the script is running as expect; e.g. 10000
                    print('converted events: ', CountedEvents)
                if CountedEvents  == NumberOfEvents:    #unpack only the provided NumberOfEvents
                    print('script stopped after the provided number of events:', NumberOfEvents)
                    break #break instead of sys.exit() to continue below with the 'if D_eventsLessWordsThanExpected'
                CountedEvents += 1
            elif fpgaFound == 1:    #line with data (just after the FPGA id); write to respective file: event number + needed data
                currentFpga = L_onlyFPGAs[indexOfCurrentFPGA]
                L_words = eval(line)
                for item in L_FPGAs:    #check if the FPGA is a tdc or adc addon
                    if   currentFpga in item[1] and item[0] == 'tdc':
                        result = TDC(L_words, D_CalibFTime, DebugMode)
                        L_f_OUT[indexOfCurrentFPGA].write(f"{event}    {result}\n")
                    elif currentFpga in item[1] and item[0] == 'adc':
                        result = ADC(L_words, D_eventsLessWordsThanExpected, DebugMode)
                        L_f_OUT[indexOfCurrentFPGA].write(f"{event}    {result}\n")
                    elif currentFpga in item[1] and item[0] == 'central':    #item[0] -> 'central', item[1] -> ['c001']
                        L_peripheralFPGAs = item[2]                          #item[2] -> ['a001', 'a002', 'a003', 'a004']
                        ##############
                        ############## (alternative probably faster)
                        #ALTERNATIVE1: search indexes of all fpgas by name; without cross check with the provided number of words for each fpga
                        #L_temp = [word[HEXlettersForNumberOfWords:] for word in L_words]    #list with only the last 4 letters of each word
                        #try:
                        #    L_indexWordFPGAs = [L_temp.index(Fpga,3) for Fpga in L_peripheralFPGAs]    #indexes of peripheral fpgas only; e.g. [4, 9, 17, 24]; .index(Fpga,3) -> to skip the first 3+1 words of the header (otherwise the index of '0000c001' (of the central fpga in the header) will be provided)
                        #except ValueError as valErr:
                        #    print(f"{valErr} (of a central FPGA): {L_temp} -> check the provided FPGAs in runUnpacker.py!\nAborting...")
                        #    sys.exit()
                        #L_L_wordsPerFPGA = [L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]] for i in range(3)]    #[L_words_periph1, L_words_periph2, L_words_periph3]
                        #L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[-1]:-2])    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]; -2 -> to remove ['00015555', '00000001']
                        ##############
                        ##############
                        #ALTERNATIVE2: search only the index of the 1st (peripheral) fpga by name; the other indexes are obtained via the provided number of words for each fpga
                        L_indexWordFPGAs = [[word[HEXlettersForNumberOfWords:] for word in L_words].index(L_peripheralFPGAs[0])]    #list with only the index of the 1st periph fpga; e.g. [4]
                        #L_wordsHeader    = L_words[0:L_indexWordFPGAs[0]]    #don't care; e.g. ['00000F9C', '00020011', '0000c001', '04601c1f']
                        L_L_wordsPerFPGA = []    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]
                        for i in range(4):    #[0,1,2,3]; one less than in case of 'central_CTS FPGA' because with a 'central FPGA' there are no words from the CTS after the 4 peripheral fpgas
                            numberOfWords = int(L_words[L_indexWordFPGAs[i]][:HEXlettersForNumberOfWords], 16) +1    #+1 -> to include the 1st word of the fpga (e.g. '0002a001')
                            L_indexWordFPGAs.append(L_indexWordFPGAs[i] + numberOfWords)    #the last append will be the index of '00015555'; e.g. [4, 9, 17, 24, 29]
                            L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]])
                        totalNumberOfWords   = int(L_words[0], 16) // m      #e.g. '00000f88' /4 = 3976/4 = 994 words for this event
                        countedNumberOfWords = L_indexWordFPGAs[-1] +1 +1    #+1 -> started to count at '0'; +1 -> to include the last word (after '00015555'): '00000001'
                        if totalNumberOfWords != countedNumberOfWords:
                            print(f'Number of words found in event {event}: {countedNumberOfWords} (for the central FPGA: {currentFpga}),',
                            f'while the expected is {totalNumberOfWords} (provided by the 1st word of the event)\naborting...')
                            sys.exit()
                        ##############
                        ##############
                        for ind, FpGa in enumerate(L_peripheralFPGAs):    #process data (L_L_wordsPerFPGA) and write to respective files
                            for vals in L_FPGAs:    #index of L_peripheralFPGAs = index of L_L_wordsPerFPGA (without central fpga); index of L_onlyFPGAs = index of L_f_OUT (central at the beginning)
                                if FpGa in vals[1] and vals[0] == 'tdc':   #this is why a periph fpga (e.g. 'a001') must be mentioned in two places in L_FPGAs: e.g. [('central', ['c001'], ['a001', 'a002', 'a003', 'a004']), ('tdc', ['a001', 'a002', 'a003', 'a004', 'c000'])]
                                    result = TDC(L_L_wordsPerFPGA[ind], D_CalibFTime, DebugMode)
                                elif FpGa in vals[1] and vals[0] == 'adc':    #issue: L_L_wordsPerFPGA[ind] doesn't have the same structure than an L_words from a normal subevent -> few words must be inserted at the beginning
                                    newNumberOfWords = L_L_wordsPerFPGA[ind][0][:HEXlettersForNumberOfWords]    #newNumberOfWords doesn't include the 1st word; e.g. '03c0a004'
                                    L_forADC = [newNumberOfWords, 'empty', FpGa] + L_L_wordsPerFPGA[ind]    #e.g. ['03c0', 'empty', 'a004'] + ['03c0a004',...]
                                    result = ADC(L_forADC, D_eventsLessWordsThanExpected,  DebugMode, From = 'central')
                                #elif FpGa in vals[1] and vals[0] == 'central':    #can't happen since we are iterating only with L_peripheralFPGAs; nothing will be written in the file of the central fpga
                            indexOfCurrentFPGA = L_onlyFPGAs.index(FpGa)    #change the value of indexOfCurrentFPGA -> we don't want the index of the central fpga but the one of each periph fpga
                            L_f_OUT[indexOfCurrentFPGA].write(f"{event}    {result}\n")    #result = None if nothing returned
                    elif currentFpga in item[1] and item[0] == 'central_CTS':    #item[0] -> 'central_CTS', item[1] -> ['c001']
                        L_peripheralFPGAs       = item[2]                    #item[2] -> ['a001', 'a002', 'a003', 'a004']
                        L_PeriphAndCentralFPGAs = item[2] + item[1]          #['a001', 'a002', 'a003', 'a004', 'c001']    (central fpga at the end; while L_onlyFPGAs has the central at the end)
                        ##############
                        ############## (alternative probably faster)
                        #ALTERNATIVE1: search indexes of all fpgas by name; without cross check with the provided number of words for each fpga
                        #L_temp = [word[HEXlettersForNumberOfWords:] for word in L_words]    #only the last 4 letters of each word
                        #try:
                        #    L_indexWordFPGAs = [L_temp.index(Fpga,3) for Fpga in L_PeriphAndCentralFPGAs]    #indexes of all fpgas; e.g. [4, 7, 10, 13, 974]; .index(Fpga,3) -> to skip the first 3+1 words of the header (otherwise the index of '0000c001' (of the central in the header) will be provided)
                        #except ValueError as valErr:
                        #    print(f"{valErr} (of a central_CTS FPGA): {L_temp} -> check the provided FPGAs in runUnpacker.py!\nAborting...")
                        #    sys.exit()
                        #L_L_wordsPerFPGA = [L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]] for i in range(4)]    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4]
                        #L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[-1]:-2])    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4, L_words_central_CTS]; -2 -> to remove ['00015555', '00000001']
                        ##############
                        ############## (probably slower but more secure)
                        #ALTERNATIVE2: search only the index of the 1st (peripheral) fpga by name; the other indexes are obtained via the provided number of words for each fpga



                        #L_indexWordFPGAs = [[word[HEXlettersForNumberOfWords:] for word in L_words].index(L_peripheralFPGAs[0])]    #list with only the index of the 1st periph fpga; e.g. [4]

                        #issue in this case (fpga = a001): ['00001e90', '00020011', '0000c001', 'f768a001', '0004a001',...
                        #force position of 1st fpga in position 4
                        L_indexWordFPGAs = [4]



                        #L_wordsHeader    = L_words[0:L_indexWordFPGAs[0]]    #don't care; e.g. ['00000F9C', '00020011', '0000c001', '04601c1f']
                        L_L_wordsPerFPGA = []    #[L_words_periph1, L_words_periph2, L_words_periph3, L_words_periph4, L_words_central_CTS]
                        for i in range(5):    #[0,1,2,3,4]
                            numberOfWords = int(L_words[L_indexWordFPGAs[i]][:HEXlettersForNumberOfWords], 16) +1    #+1 -> to include the 1st word of the fpga (e.g. '0002a001')
                            L_indexWordFPGAs.append(L_indexWordFPGAs[i] + numberOfWords)    #the last append will be the index of '00015555'; e.g. [4, 7, 10, 13, 974, 992]
                            L_L_wordsPerFPGA.append(L_words[L_indexWordFPGAs[i]:L_indexWordFPGAs[i+1]])
                        totalNumberOfWords   = int(L_words[0], 16) // m      #e.g. '00000f88' /4 = 3976/4 = 994 words for this event
                        countedNumberOfWords = L_indexWordFPGAs[-1] +1 +1    #+1 -> started to count at '0'; +1 -> to include the last word (after '00015555'): '00000001'
                        if totalNumberOfWords != countedNumberOfWords:
                            print(f'Number of words found in event {event}: {countedNumberOfWords} (for the central_CTS FPGA: {currentFpga}),',
                            f'while the expected is {totalNumberOfWords} (provided by the 1st word of the event)\naborting...')
                            #sys.exit()
                        ##############
                        ##############
                        for ind, FpGa in enumerate(L_PeriphAndCentralFPGAs):    #process data (L_L_wordsPerFPGA) and write to respective files
                            for vals in L_FPGAs:    #index of L_PeriphAndCentralFPGAs = index of L_L_wordsPerFPGA (central at the end); index of L_onlyFPGAs = index of L_f_OUT (central at the beginning)
                                if FpGa in vals[1] and vals[0] == 'tdc':   #this is why a periph fpga (e.g. 'a001') must be mentioned in two places in L_FPGAs: e.g. [('central_CTS', ['c001'], ['a001', 'a002', 'a003', 'a004']), ('tdc', ['a001', 'a002', 'a003']), ('adc', ['a004'])]
                                    result = TDC(L_L_wordsPerFPGA[ind], D_CalibFTime, DebugMode)
                                elif FpGa in vals[1] and vals[0] == 'adc':    #issue: L_L_wordsPerFPGA[ind] doesn't have the same structure than an L_words from a normal subevent -> few words must be inserted at the beginning
                                    newNumberOfWords = L_L_wordsPerFPGA[ind][0][:HEXlettersForNumberOfWords]    #newNumberOfWords doesn't include the 1st word; e.g. '03c0a004'
                                    L_forADC = [newNumberOfWords, 'empty', FpGa] + L_L_wordsPerFPGA[ind]    #e.g. ['03c0', 'empty', 'a004'] + ['03c0a004',...]
                                    result = ADC(L_forADC, D_eventsLessWordsThanExpected,  DebugMode, From = 'central_CTS')
                                elif FpGa in vals[1] and vals[0] == 'central_CTS':    #the central might have TDC chs! -> change code: in principle send it normally to TDC()
                                    result = CENTRAL_CTS(L_L_wordsPerFPGA[ind])
                            indexOfCurrentFPGA = L_onlyFPGAs.index(FpGa)    #change the value of indexOfCurrentFPGA -> we don't want the index of the central fpga but the one of each periph fpga
                            L_f_OUT[indexOfCurrentFPGA].write(f"{event}    {result}\n")    #result = None if nothing returned
                fpgaFound = 0
            elif event:    #line just after a 'seqNr (EVENT NUMBER)' -> check if the provided FPGA in the current line is in the list given in runUnpacker.py
                try:
                    indexOfCurrentFPGA = L_onlyFPGAs.index(line[:8].lstrip('0'))    # index of the fpga in L_onlyFPGAs = index of the file in L_f_OUT where next line should be written
                except ValueError as valErr:
                    print(f"{valErr}: {L_onlyFPGAs} -> check the provided 'L_fpgas' in runUnpacker.py!\nAborting...")    #e.g.: '0000c001' is not in list: ['0000c002', '0000a001', '0000a002', '0000a003', '0000a004']
                    sys.exit()
                fpgaFound = 1
            else:
                print(f"something wrong with the file: {InputPath}\n('seqNr (EVENT NUMBER)' not found in the 1st line)\n"
                       "if a folder was provided as inputPath, be sure all files ending with '.txt' are to be converted\nAborting...")
                sys.exit()
        if D_eventsLessWordsThanExpected:
            print(f'Some events have less words than the provided by the 1st subevent word. Number of events (with less words) per ADC addon:\n{D_eventsLessWordsThanExpected}')
        print('converted events: ', CountedEvents -1)    #-1: explained already for the unpacked events -> the hld file ends always with an EMPTY event header


def TDC(L_words, D_CalibFtime=None, debuggMode=None, T_event_Path=None):
    indexes     = [index for index, word in enumerate(L_words) if word[0] == '2']    #only the 1st index will be used
    if not indexes:
        return 1    #this fpga is not a TDC
    fpgaName = L_words[0][HEXlettersForNumberOfWords:]    #needed for the 'final' dict of calibrationFTime.tdc (in case of several TDCs in the setup), e.g.: {'a001': {0: [102, 469, 367], 1: [16, 478, 462], 2: [16, 473, 457]}, 'a002': {0: [410, 418, 8]}, 'a003': {0: [459, 469, 10]}}
    epochFound  = 0
    L_time      = []
    for word in L_words[indexes[0]+1:]:    #+1 para começar com o word a aseguir a '2...'
        if word[0] == '6':    #EPOCH Counter
            if debuggMode:
                L_time.append(word)
            else:
                epochTime = int(word[1:],base=16) *10240    #[ns]; 10.24us = 10240ns
            epochFound = 1
        elif epochFound == 1 and word[0] == '8':    #TIME Data
            if debuggMode:
                L_time.append(word)
            else:
                binary_word = bin(int(word, base=16))[2:]    #e.g. 800E39CE -> 100 0000000 0011100011 1 00111001110
                channel     = int(binary_word[3:10],base=2)
                fineTime    = int(binary_word[10:20],base=2)
                edge        = int(binary_word[20])    # =1 -> rising; =0 -> falling
                coarseTime  = int(binary_word[21:],base=2) *5    #[ns]; convert binary to decimal and *5ns (clock of 200 MHz)
                if T_event_Path:    #write in file fineTime values for calibration
                    if fineTime < 521:    #Jan: some channels sometimes show a value > 520 -> these are decoding errors
                        T_event_Path[1].write(f"{T_event_Path[0]:6d} {channel:3d} {edge:2d} {fineTime:4d}\n")
                    else:
                        print(f"finetime value found above the expected maximum (520): {fineTime}")
                        print(f"a 'nan' value will be written instead (event ch edge finetime): {T_event_Path[0]:6d} {channel:3d} {edge:2d}  nan\nin the file: {T_event_Path[1].name}")
                        T_event_Path[1].write(f"{T_event_Path[0]:6d} {channel:3d} {edge:2d}  nan\n")
                    continue    #no need to proceed when running TDC() from function calibrateFineTime()
                if D_CalibFtime:    #calibrationFTime.tdc and the dict D_CalibFtime are diff than None -> the parameters to calibrate the fine time of each ch can be retrieved
                    paramCalib_lowestFTimeBin = D_CalibFtime[fpgaName][channel][0]    #D_CalibFtime, e.g. {'a001': {0: [106, 112, 6], 1: [89, 466, 377], 2: [147, 473, 326], 3: [79, 476, 397], 4: [63, 472, 409]}, 'a002': {}, 'a003': {}}
                    paramCalib_rangeFTimeBins = D_CalibFtime[fpgaName][channel][2]    #=5ns
                    fineTime = (fineTime - paramCalib_lowestFTimeBin) * (5 / paramCalib_rangeFTimeBins)
                    #print(f'{fineTime:.3f}')
                else:
                    fineTime = 0    # no calibration
                if channel == 0:    #L_words is sorted by ch i.e. it always starts from ch 0
                    RefTimeToSubtract = epochTime + coarseTime - fineTime
                    #L_time.append([round(RefTimeToSubtract,3), channel, edge])    #uncomment if you want to append also the absolute time of the ref time; e.g. 1    [[180988719250, 0, 1]]
                else:
                    time = epochTime + coarseTime - fineTime - RefTimeToSubtract
                    L_time.append([round(time,3), channel, edge])    #round at the ps level
        elif epochFound:    #stop after seeing an EPOCH Counter AND then entering in this elif branch -> a word not starting with '6' or '8' was found
            break
    return L_time    #return not needed for function calibrateFineTime()


def ADC(L_words, D_eventsLessWordsThanExpected, debuggMode, From = None):
    #D_ADCch_Data = {'00': [], '01': [], '02': [], '03': [], '10': [], '11': [], '12': [], '13': [], '20': [], '21': [], '22': [], '23': [], '30': [], '31': [], '32': [], '33': [], '40': [], '41': [], '42': [], '43': [], '50': [], '51': [], '52': [], '53': [], '60': [], '61': [], '62': [], '63': [], '70': [], '71': [], '72': [], '73': [], '80': [], '81': [], '82': [], '83': [], '90': [], '91': [], '92': [], '93': [], 'a0': [], 'a1': [], 'a2': [], 'a3': [], 'b0': [], 'b1': [], 'b2': [], 'b3': []}
    D_ADCch_Data = {}
    proceed = 0
    if From == 'central_CTS' or From == 'central':   #event from a TR3 (the central fpga might be CTS or not, it is the same)
        if int(L_words[0],16) +4 == len(L_words):    #+1 to include the 1st word (e.g. '03c0a004') +3 to include the 3 added words (e.g. '03c0', 'empty', 'a004')
            proceed = 1                              #why to add these words? '03c0' to be sure the len of L_words is correct; 'a004' for D_eventsLessWordsThanExpected below
            L_words = L_words[4:]
    else:
        if int(L_words[0],16)//4 == len(L_words):
            L_words = L_words[4:-2]    #4 words of sub event header (['00000f18', '00020011', '0000a001', '07793ff2',...) +X words of data +2 at the end (..., '00015555', '00000001'])
            proceed = 1
    if proceed:
        for ADCword in L_words:
            if debuggMode:
                D_ADCch_Data.setdefault(ADCword[2:4],[]).append(ADCword)
            else:
                #D_ADCch_Data[ADCword[2:4]].append(int(ADCword[4:8],base=16))
                D_ADCch_Data.setdefault(ADCword[2:4],[]).append(int(ADCword[4:8],base=16))
        #remove the next 3 lines if it takes too much time with large files
        numberOfActiveADCchs    = len(D_ADCch_Data)
        D_ADCch_Data['CHs']     = numberOfActiveADCchs
        D_ADCch_Data['Samples'] = len(L_words) // numberOfActiveADCchs
    else:
        key = L_words[2].lstrip('0')    #key = fpga
        D_eventsLessWordsThanExpected[key] = D_eventsLessWordsThanExpected.get(key, 0) + 1    #increment each time an fpga has a event with different number of words than the expected (provided in the 1st word)
    return D_ADCch_Data


def CENTRAL_CTS(L_words):
    return L_words
