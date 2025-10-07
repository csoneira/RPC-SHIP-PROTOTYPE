#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
#############
@JPCS_02/2023
updated 10/2024
#############
Unpack & convert:
-> aditional changes can be done directly in the file runUnpacker.py (how many events to unpack...)
-> unpacked files:  dabc*.txt created in the folder hldOutFolder
-> calibration files: *.fTime and calibrationFTime.tdc in the folder hldOutFolder
-> converted files: dabc*.tdc, dabc*.adc, dabc*.central_CTS... created in the folder hldOutFolder
Compute charge and baseLine for ADC files:
-> dataframe with computed charge values will be copied to dabc*.charge files (compressed files) in the folder chargeFolder
-> dataframe with concatenated charge values of all dabc*.charge files can be copied to a dabc*_Q.mat file (one per FPGA) in the folder chargeFolder
-> dataframe with computed base line values will be copied to dabc*.bLine files (compressed files) in the folder bLineFolder
-> dataframe with concatenated base line values of all dabc*.bLine files can be copied to a dabc*_BL.mat file (one per FPGA) in the folder bLineFolder
Compute time for TDC files:
-> dataframe with computed time values will be copied to dabc*.time files (compressed files) in the folder timeFolder
-> dataframe with concatenated time values of all dabc*.time files can be copied to a dabc*_T.mat file (one per FPGA) in the folder timeFolder
plotQperStrip:
-> ADC waveforms (2chs per plot -> from superimposed readouts) + baseline subtraction + computed charge per strip + colored plot for the strip with highest charge
-> aditional changes must be done directly in the file plot.py (save or/and show figures or not, downsampling, lookuptable, which kind of plot to do...)
####
The following variables can be defined via script arguments (to be used by runUnpackAll_longRuns.py):
hldInFolder hldOutFolder compress_hldOutFolder unpack convertTime convertQandbLine plotQperStrip plotFrom plotTo saveAnalysis
syntax:
./unpackAll.py
or
./unpackAll.py 'hldInFolder' 'hldOutFolder' 'compress_hldOutFolder' 'unpack' 'convertTime' 'convertQandbLine' 'plotQperStrip' 'plotFrom' 'plotTo' 'saveAnalysis'
e.g.
./unpackAll.py /home/user/hlds_toUnpack /home/user/unpackedFiles 0 1 3 3 1 1 5 1
in case 'hldInFolder' 'hldOutFolder' are not needed (unpack = 0, saveAnalysis = 0 and compress_hldOutFolder = 0), use for instance:
./unpackAll.py - - 0 0 3 3 1 1 5 0
'hldInFolder' must be provided in case saveAnalysis was set to 1 via script arguments
'hldOutFolder' must be provided in case compress_hldOutFolder was set to 1 via script arguments
####
needed files:
runUnpacker.py
unpacker.py
computeQandBline.py
plot.py
readDataFrame.py
#############
"""

import os, sys, time, glob, datetime, shutil
import pandas   as pd
import numpy    as np
import scipy.io as sio
from collections      import OrderedDict    #as of Python 3.6, dictionaries remember the order of items inserted; dicPerEvent = OrderedDict() -> dicPerEvent = {}
from subprocess       import Popen, PIPE
from computeQandBline import QandBlinePerStrip
from plot             import plotIt
from readDataFrame    import readDFrame
t = time.time()

#############
homeOS = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/'
home   = '/home/csoneira/WORK/LIP_stuff/JOAO_SETUP/unpacker/'
savesFolder  = homeOS + 'MST_saves'        #at the end of unpacking, converting... all the created folders/files are moved to savesFolder (if saveAnalysis = 1)
hldInFolder  = home   + 'hlds_toUnpack'    #hld (input) folder; expected extension of files in the folder: *.hld; if saveAnalysis = 1 -> all the *.hld are then moved to ./hld
hldOutFolder = home   + 'unpackedFiles'    #path of the output folder for unpacked files (*.txt + *.adc + *.tdc ...)
chargeFolder = home   + 'charge'           #path of the output folder for *.charge files   (for df_charge)
bLineFolder  = home   + 'baseLine'         #path of the output folder for *.bLine files    (for df_baseLine)
timeFolder   = home   + 'time'             #path of the output folder for *.time files     (for df_time)
plotFolder   = home   + 'plots'            #path of the output folder for plots -> no figures will be saved IF not previously set to do so in plot.py
######
compress_hldOutFolder = 0    #0/1; 1: compress the folder hldOutFolder and the folder ./hlds where all the *.hld are moved to (done only if saveAnalysis = 1)
unpack                = 1    #0/1/2/3/4; 0: don't do it; 1: extract (*.hld -> *.txt) + calibrate (*.fTime + calibrationFTime.tdc) + convert  (*.adc + *.tdc); 2: extract only (*.hld -> *.txt);
                             #3: calibrate only (*.fTime + calibrationFTime.tdc); 4: convert only (*.adc + *.tdc)
                             #In the 'if unpack' below, the calibration can be set to 1 (create a new calibrationFTime.tdc -> erases previous data in this file) or 2 (append data to calibrationFTime.tdc)
convertTime           = 2    #0/1/2/3; 0: don't do it; 1: *.tdc -> *.time; 2: *.tdc -> *.time and one *_T.mat file (per TDC) with concatenated data; 3: read all *.time files and create respective *_T.mat file
convertQandbLine      = 2    #0/1/2/3; 0: don't do it; 1: *.adc -> *.charge *.bLine; 2: *.adc -> *.charge *.bLine and one *_Q.mat file (per ADC) with concatenated data; 3: create *_Q.mat and *_BL.mat files
plotQperStrip         = 0    #0/1;  *.jpg
plotFrom              = 1    #1,2,3... (1 = first event in the file (which may have different 'id' (depending if it is the first hld of the run or not))
plotTo                = 5   #1,2,3...
saveAnalysis          = 1    #0/1
#############

if len(sys.argv) == 11:     #e.g. ./unpackAll.py /home/user/hlds_toUnpack /home/user/unpackedFiles 0 1 3 3 1 1 5 1
    hldInFolder           = sys.argv[1]
    hldOutFolder          = sys.argv[2]
    compress_hldOutFolder = int(sys.argv[ 3])
    unpack                = int(sys.argv[ 4])
    convertTime           = int(sys.argv[ 5])
    convertQandbLine      = int(sys.argv[ 6])
    plotQperStrip         = int(sys.argv[ 7])
    plotFrom              = int(sys.argv[ 8])
    plotTo                = int(sys.argv[ 9])
    saveAnalysis          = int(sys.argv[10])
elif len(sys.argv) == 1:    #the values defined above will be used
    pass
else:
    print("\nUsages:\n./unpackAll.py\n./unpackAll.py 'hldInFolder' 'hldOutFolder' 'compress_hldOutFolder' 'unpack' 'convertTime' 'convertQandbLine' 'plotQperStrip' 'plotFrom' 'plotTo' 'saveAnalysis'")
    sys.exit()

if unpack:
    if   unpack == 1:    #unpack (*.hld -> *.txt) + calibrate (*.fTime) (see below, =1->start a new calibrationFTime.tdc; =2->append data to calibrationFTime.tdc) + convert (*.adc + *.tdc)
        cmd = Popen(home + 'runUnpacker.py ' + hldInFolder + ' ' + hldOutFolder + ' 1 2 1', shell=True, stderr=PIPE)    #don't PIPE the stdout otherwise it is provided only at the end of the process...
    elif unpack == 2:    #unpack only (*.hld -> *.txt)
        cmd = Popen(home + 'runUnpacker.py ' + hldInFolder + ' ' + hldOutFolder + ' 1 0 0', shell=True, stderr=PIPE)
    elif unpack == 3:    #calibrate only (*.fTime); the value for calibration can be =1 (start a new calibrationFTime.tdc each time this script is run) or =2 (append data to calibrationFTime.tdc)
        cmd = Popen(home + 'runUnpacker.py ' + hldInFolder + ' ' + hldOutFolder + ' 0 2 0', shell=True, stderr=PIPE)    #must be =2 for long runs (using runUnpackAll_longRuns.py to call unpackAll.py)
    elif unpack == 4:    #convert only (*.adc + *.tdc)
        cmd = Popen(home + 'runUnpacker.py ' + hldInFolder + ' ' + hldOutFolder + ' 0 0 1', shell=True, stderr=PIPE)
    STDout, STDerr = cmd.communicate()
    if STDerr:
        print('Errors found with the cmd: %s\n%s\n' % (cmd, STDerr.decode()))
        sys.exit()

############
#LOOKUPTABLE
#I (strip lado gás) ...                                                                                                                 XXIV
stripsNamesbot = ['Ib','IIb','IIIb','IVb','Vb','VIb','VIIb','VIIIb','IXb','Xb','XIb','XIIb','XIIIb','XIVb','XVb','XVIb','XVIIb','XVIIIb','XIXb','XXb','XXIb','XXIIb','XXIIIb','XXIVb']
#1ST SETUP (caixa pequena com os dois planos de strips finas na mesma dir, um por cima e outro por baixo de uma RPC) -> tem de ser usado com computeQandBline_narrowStripsOnly.py
#ADCsBot = ['80','81','82','83','b0','b1','b2','b3','70','71','72','73','60','61','62','63','00','01','02','03','20','21','22','23']
#TEST FOR SWITCHED CABLES ONLY:
#ADCsBot = ['10','11','12','13','30','31','32','33','40','41','42','43','50','51','52','53','90','91','92','93','a0','a1','a2','a3']
#NARROW-STRIP PLANES TOGETHER WITH LARGE-STRIP PLANE (06/2023):
#ADCsBot = ['23','22','21','20','03','02','01','00','63','62','61','60','73','72','71','70','b3','b2','b1','b0','83','82','81','80']
#130x90cm² RPCs (last setup):
ADCsBot = ['10','11','12','13','30','31','32','33','40','41','42','43','50','51','52','53','90','91','92','93','a0','a1','a2','a3']


stripsNamesTop = ['It','IIt','IIIt','IVt','Vt','VIt','VIIt','VIIIt','IXt','Xt','XIt','XIIt','XIIIt','XIVt','XVt','XVIt','XVIIt','XVIIIt','XIXt','XXt','XXIt','XXIIt','XXIIIt','XXIVt']
#1ST SETUP (caixa pequena com os dois planos de strips finas na mesma dir, um por cima e outro por baixo de uma RPC) -> tem de ser usado com computeQandBline_narrowStripsOnly.py
#ADCsTop = ['a3','a2','a1','a0','93','92','91','90','53','52','51','50','43','42','41','40','33','32','31','30','13','12','11','10']
#TEST FOR SWITCHED CABLES ONLY:
#ADCsTop = ['23','22','21','20','03','02','01','00','63','62','61','60','73','72','71','70','b3','b2','b1','b0','83','82','81','80']
#NARROW-STRIP PLANES TOGETHER WITH LARGE-STRIP PLANE (06/2023):
#ADCsTop = ['a3','a2','a1','a0','93','92','91','90','53','52','51','50','43','42','41','40','33','32','31','30','13','12','11','10']
#130x90cm² RPCs (last setup):
ADCsTop = ['80','81','82','83','b0','b1','b2','b3','70','71','72','73','60','61','62','63','00','01','02','03','20','21','22','23']
############


if convertTime == 1 or convertTime == 2:    # *.tdc -> *.time
    filesForTime = glob.glob(hldOutFolder + '/*.tdc')    #expected files: dabc*_FPGA.tdc and calibrationFTime.tdc
    if filesForTime:
        if not os.path.exists(timeFolder): os.makedirs(timeFolder)
        L_fpgas = []                                         #e.g. ['a003', 'a001', 'a002']
        for File in filesForTime:                            #create first a list of fpgas based on the file names in the provided folder
            fileName = File.split('/')[-1].split('.')[0]     #e.g. dabc23078075442_a003
            fileNameSplitted = fileName.split('_')           #e.g. ['dabc23078075442', 'a003']
            if len(fileNameSplitted) == 2:                   #if=1 -> calibration file (calibrationFTime.tdc (don't use '_' for the calib. file!)) -> skip
                L_fpgas.append(fileNameSplitted[1])
        dic_DFramesForEachfpga = {fpGa: [] for fpGa in L_fpgas}    #e.g. {'a001': [], 'a002': [], 'a003': []}; with dict comprehension the empty lists are not the same list object; here all the lists are the same object: dic_DFramesForEachfpga = dict.fromkeys(L_fpgas,[])
        filesForTime.sort()
        L_files=[]
        for File in filesForTime:                      #create a dataframe based on the data of each dabc*_FPGA.tdc files
            fileName = File.split('/')[-1].split('.')[0]
            fileNameSplitted = fileName.split('_')     #e.g. ['dabc23078075442', 'a001']
            if len(fileNameSplitted) == 2:
                fpga = fileNameSplitted[1]
                with open(File, 'r+') as f_IN:
                    dicPerFile  = OrderedDict()                   #keys -> event number; vals ->  dic (dicPerEvent) with keys: tdc chs and vals: tdc time
                    for line in f_IN:
                        dicPerEvent = OrderedDict()
                        L_line = line.split('    ')    #e.g. ['1', '[[-6289.865, 1, 1], [-6118.105, 1, 0], [-6291.089, 2, 1], [-6057.588, 2, 0]]\n']
                        event = L_line[0]
                        list  = L_line[1]    #e.g. [[-6289.865, 1, 1], [-6118.105, 1, 0], [-6291.089, 2, 1], [-6057.588, 2, 0], [-6291.832, 3, 1], [-6182.479, 3, 0]]
                        if list == '[]\n':    #empty line; in this event there was only the time of the ref time which results in a emtpy event (e.g.: 14590    []) in the file dabc*_FPGA.tdc
                            dicPerEvent['emptyEvent'] = 1
                        else:
                            dicPerEvent['emptyEvent'] = 0
                        for L in eval(list):
                            if (L[2] == 1) and ('l' + str(L[1]) not in dicPerEvent):      #save only the first leading edge time of each channel (in case the TDC buffer has a multi-hit for this ch, only the 1st hit is saved)
                                dicPerEvent['l' + str(L[1])] = L[0]
                            elif (L[2] == 1) and ('l' + str(L[1]) in dicPerEvent):        #leading after an already saved one, if this ch doesn't have a trailing, set it to nan
                                if 't' + str(L[1]) not in dicPerEvent:
                                    dicPerEvent['t' + str(L[1])] = np.nan
                            elif (L[2] == 0) and ('t' + str(L[1]) not in dicPerEvent):    #save only the first trailing edge time of each channel (it might be already nan, if there was first 2 leading)
                                if 'l' + str(L[1]) not in dicPerEvent:    #in the case a trailing appears before a leading, set the leading to nan; not sure if this can happen...
                                    dicPerEvent['l' + str(L[1])] = np.nan
                                dicPerEvent['t' + str(L[1])] = L[0]    #e.g. {'l1': -6289.865, 't1': -6118.105, 'l2': -6291.089, 't2': -6057.588, 'l3': -6291.832, 't3': -6182.479}
                        dicPerFile[event] = dicPerEvent    #e.g. {'1': {'l1': -6289.865, 't1': -6118.105, 'l2': -6291.089, 't2': -6057.588,...}, '2': {},..., '1326': {}}
                df_Time = pd.DataFrame.from_dict(dicPerFile, orient='index')              #rows -> events, cols -> tdc chs (l1, t1, l2, t3...)
                df_Time.reset_index(inplace=True)
                df_Time = df_Time.rename(columns = {'index':'EventPerFile'})
                df_Time['EventPerFile'] = df_Time['EventPerFile'].astype('int')    #se um run foi relançado, pode haver 'EventPerFile' com o mesmo nº de evento
                df_Time = df_Time.sort_values('EventPerFile')    #tem de ser feito um sort de eventos senão um evento com nan pode ir parar ao fim do DF; como o sort é feito a nível de cada ficheiro -> não se perde a ordem de ocorrencia dos eventos
                df_Time.to_pickle(timeFolder  + '/' + fileName + '.time')             #the file dabc*_FPGA.time is only created if df_Time not empty
                if convertTime == 2:    #append dataframes to the respective fpga; they will be concatenated and saved later
                    dic_DFramesForEachfpga[fpga].append(df_Time)
                    if fileNameSplitted[0] not in L_files:
                        L_files.append(fileNameSplitted[0])                           #e.g. ['dabc23078075442'] -> in this case only one file in the folder
        if convertTime == 2:
            for key,val in dic_DFramesForEachfpga.items():
                df = pd.concat((DF for DF in val), axis=0, ignore_index=True)    #ignore_index=True -> nova numeração para o index de 0 a ...
                #df.reset_index(inplace=True)    #in case we want a col with a list of all events (equal to the number of rows, so this col 'EventFull' is optional...)
                #df= df.rename(columns = {'index':'EventFull'})
                #df['EventFull'] = df['EventFull'].astype('int') +1    #+1 -> to start from 1 and not 0
                Dic = df.to_dict('list')    #keys: 'Event', 'l1', 'l2', 'l3'...; vals: list with all the values of this key, e.g. for key 'Event': [1, 2, 3,..., 1325, 1326]
                Dic['files'] = [file + '_' + key + '.tdc' for file in L_files]    #add key 'files' to Dic, with all the file names
                if len(L_files) == 1:    #one file only
                    fileNameMat = timeFolder + '/' + L_files[0] + '_' + key + '_T.mat'        #e.g. /home/jpcs/Desktop/RPCs/unpackerTRB3_largeDatasets/time/dabc23078075442_a001_T.mat
                else:
                    fileNameMat = timeFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_T.mat'    #e.g. .../time/dabc23078075442-dabc23078172733_a001_T.mat
                sio.savemat(fileNameMat, Dic, oned_as='column')
    else:
        print('Nothing to do despite convertTime was set to 1')
    print(f"elapsed time (convertTime): {time.time() - t:.3f} s")
elif convertTime == 3:
    filesToReadDfTime = glob.glob(timeFolder + '/*.time')    #expected files in this folder: dabc*_FPGA.time and dabc*_FPGA_T.mat
    filesToReadDfTime.sort()    #must be sorted to have sorted events too
    dicFPGAsAndDFrames = {}   #{'a001': dataframe_allOrderedEvents_a001, a002': full dataframe_allOrderedEvents_a002,...}
    L_files=[]
    for filePath in filesToReadDfTime:
        filename = filePath.split('/')[-1].split('.')[0]
        fileNameSplitted = filename.split('_')    #e.g. ['dabc23258093311', 'a001']
        fileName = fileNameSplitted[0]
        fileFpga = fileNameSplitted[1]
        L_files.append(fileName)
        if fileFpga not in dicFPGAsAndDFrames.keys():
            dicFPGAsAndDFrames[fileFpga] = readDFrame(filePath)
        else:
            df = pd.concat([dicFPGAsAndDFrames[fileFpga], readDFrame(filePath)], axis=0, ignore_index=True)
            dicFPGAsAndDFrames[fileFpga] = df
    L_files = list(np.unique(L_files))    #e.g. ['dabc23258093311', 'dabc23258154558',..., 'dabc23262000659']; the same file name may appear more than once in L_files if there are several TDCs
    for key,val in dicFPGAsAndDFrames.items():    #key -> fpga; val -> full dataframe
        if len(L_files) == 1:    #one file only
            fileNameMat = timeFolder + '/' + L_files[0] + '_' + key + '_T.mat'
        else:
            fileNameMat = timeFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_T.mat'
        Dic = val.to_dict('list')    #with 'val' the full dataframe
        Dic['files'] = [file + '_' + key  + '.tdc' for file in L_files]
        sio.savemat(fileNameMat, Dic, oned_as='column')


if convertQandbLine == 1 or convertQandbLine == 2:    # *.adc -> *.charge *.bLine; if convertQandbLine =2, create also *_FPGA_Q.mat and *_FPGA_BL.mat
    filesToComputeChargeAndBLine = glob.glob(hldOutFolder + '/*.adc')
    if filesToComputeChargeAndBLine:
        if not os.path.exists(chargeFolder): os.makedirs(chargeFolder)
        if not os.path.exists(bLineFolder):  os.makedirs(bLineFolder)
        L_fpgas = []
        for File in filesToComputeChargeAndBLine:
            fileName = File.split('/')[-1].split('.')[0]
            fileNameSplitted = fileName.split('_')
            L_fpgas.append(fileNameSplitted[1])
        dic_DFramesForEachfpga_charge = {fpGa: [] for fpGa in L_fpgas}
        dic_DFramesForEachfpga_bline  = {fpGa: [] for fpGa in L_fpgas}
        filesToComputeChargeAndBLine.sort()
        L_files=[]
        for File in filesToComputeChargeAndBLine:
            fileName = File.split('/')[-1].split('.')[0]
            fileNameSplitted = fileName.split('_')
            fpga = fileNameSplitted[1]
            df_BaseLine, df_Charge = QandBlinePerStrip(File)
            if not df_Charge.empty:
                df_Charge.to_pickle(chargeFolder  + '/' + fileName + '.charge')
                df_BaseLine.to_pickle(bLineFolder + '/' + fileName + '.bLine')
                if convertQandbLine == 2:
                    dic_DFramesForEachfpga_charge[fpga].append(df_Charge)
                    dic_DFramesForEachfpga_bline[fpga].append(df_BaseLine)
                    if fileNameSplitted[0] not in L_files:
                        L_files.append(fileNameSplitted[0])
        dic_DFramesForEachfpga_charge = {k: v for k, v in dic_DFramesForEachfpga_charge.items() if v}
        dic_DFramesForEachfpga_bline  = {k: v for k, v in dic_DFramesForEachfpga_bline.items() if v}
        if convertQandbLine == 2:    #concact & save to *_Q.mat file
            L_allADCs   = ['EventPerFile'] + ADCsBot        + ADCsTop           #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
            L_allStrips = ['EventPerFile'] + stripsNamesbot + stripsNamesTop    #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
            for key,val in dic_DFramesForEachfpga_charge.items():
                df = pd.concat((DF for DF in val), axis=0, ignore_index=True)
                #df.reset_index(inplace=True)    #in case we want a col with a list of all events (equal to the number of rows, so this col 'EventFull' is optional...)
                #df= df.rename(columns = {'index':'EventFull'})
                #df['EventFull'] = df['EventFull'].astype('int') +1    #+1 -> to start from 1 and not 0
                Dic = df.to_dict('list')    #'dict', 'list', 'series', 'split', 'records', and 'index'; keys: ADC names (e.g. '80'), vals: list of all Q values of each key
                Dic = dict((L_allStrips[L_allADCs.index(key)], value) for (key, value) in Dic.items())    #matlab drops columns with names starting with integers (e.g. '80')! -> apply lookuptable here & change column names (starting with one letter)
                Dic['files'] = [file + '_' + key + '.adc' for file in L_files]
                if len(L_files) == 1:    #one file only
                    fileNameMat = chargeFolder + '/' + L_files[0] + '_' + key + '_Q.mat'
                else:
                    fileNameMat = chargeFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_Q.mat'
                sio.savemat(fileNameMat, Dic, oned_as='column')
            for key,val in dic_DFramesForEachfpga_bline.items():
                df = pd.concat((DF for DF in val), axis=0, ignore_index=True)
                Dic = df.to_dict('list')
                Dic = dict((L_allStrips[L_allADCs.index(key)], value) for (key, value) in Dic.items())
                Dic['files'] = [file + '_' + key + '.adc' for file in L_files]
                if len(L_files) == 1:    #one file only
                    fileNameMat = bLineFolder + '/' + L_files[0] + '_' + key + '_BL.mat'
                else:
                    fileNameMat = bLineFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_BL.mat'
                sio.savemat(fileNameMat, Dic, oned_as='column')
    else:
        print('Nothing to do despite convertQandbLine was set to 1')
    print(f"elapsed time (convertQandbLine): {time.time() - t:.3f} s")
elif convertQandbLine == 3:
    filesToReadDfCharge = glob.glob(chargeFolder + '/*.charge')    #expected files in this folder: dabc*_FPGA.charge and dabc*_FPGA_Q.mat
    filesToReadDfCharge.sort()    #must be sorted to have sorted events too
    dicFPGAsAndDFrames = {}   #{'a001': dataframe_allOrderedEvents_a001, a002': full dataframe_allOrderedEvents_a002,...}
    L_files=[]
    for filePath in filesToReadDfCharge:
        filename = filePath.split('/')[-1].split('.')[0]
        fileNameSplitted = filename.split('_')    #e.g. ['dabc23258093311', 'a001']
        fileName = fileNameSplitted[0]
        fileFpga = fileNameSplitted[1]
        L_files.append(fileName)
        if fileFpga not in dicFPGAsAndDFrames.keys():
            dicFPGAsAndDFrames[fileFpga] = readDFrame(filePath)
        else:
            df = pd.concat([dicFPGAsAndDFrames[fileFpga], readDFrame(filePath)], axis=0, ignore_index=True)
            dicFPGAsAndDFrames[fileFpga] = df
    L_files = list(np.unique(L_files))    #e.g. ['dabc23258093311', 'dabc23258154558',..., 'dabc23262000659']; the same file name may appear more than once in L_files if there are several ADCs
    for key,val in dicFPGAsAndDFrames.items():    #key -> fpga; val -> full dataframe
        if len(L_files) == 1:    #one file only
            fileNameMat = chargeFolder + '/' + L_files[0] + '_' + key + '_Q.mat'
        else:
            fileNameMat = chargeFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_Q.mat'
        Dic = val.to_dict('list')    #with 'val' the full dataframe
        L_allADCs   = ['EventPerFile'] + ADCsBot        + ADCsTop           #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
        L_allStrips = ['EventPerFile'] + stripsNamesbot + stripsNamesTop    #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
        Dic = dict((L_allStrips[L_allADCs.index(key)], value) for (key, value) in Dic.items())    #matlab drops columns with names starting with integers (e.g. '80')! -> apply lookuptable here & change column names (starting with one letter)
        Dic['files'] = [file + '_' + key  + '.adc' for file in L_files]
        sio.savemat(fileNameMat, Dic, oned_as='column')
    filesToReadDfBLine = glob.glob(bLineFolder + '/*.bLine')    #expected files in this folder: dabc*_FPGA.bLine and dabc*_FPGA_BL.mat
    filesToReadDfBLine.sort()    #must be sorted to have sorted events too
    dicFPGAsAndDFrames = {}   #{'a001': dataframe_allOrderedEvents_a001, a002': full dataframe_allOrderedEvents_a002,...}
    L_files=[]
    for filePath in filesToReadDfBLine:
        filename = filePath.split('/')[-1].split('.')[0]
        fileNameSplitted = filename.split('_')    #e.g. ['dabc23258093311', 'a001']
        fileName = fileNameSplitted[0]
        fileFpga = fileNameSplitted[1]
        L_files.append(fileName)
        if fileFpga not in dicFPGAsAndDFrames.keys():
            dicFPGAsAndDFrames[fileFpga] = readDFrame(filePath)
        else:
            df = pd.concat([dicFPGAsAndDFrames[fileFpga], readDFrame(filePath)], axis=0, ignore_index=True)
            dicFPGAsAndDFrames[fileFpga] = df
    L_files = list(np.unique(L_files))    #e.g. ['dabc23258093311', 'dabc23258154558',..., 'dabc23262000659']; the same file name may appear more than once in L_files if there are several ADCs
    for key,val in dicFPGAsAndDFrames.items():    #key -> fpga; val -> full dataframe
        if len(L_files) == 1:    #one file only
            fileNameMat = bLineFolder + '/' + L_files[0] + '_' + key + '_BL.mat'
        else:
            fileNameMat = bLineFolder + '/' + L_files[0] + '-' + L_files[-1] + '_' + key + '_BL.mat'
        Dic = val.to_dict('list')    #with 'val' the full dataframe
        L_allADCs   = ['EventPerFile'] + ADCsBot        + ADCsTop           #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
        L_allStrips = ['EventPerFile'] + stripsNamesbot + stripsNamesTop    #use ['EventFull', 'EventPerFile'] if you want to create the col 'EventFull' below
        Dic = dict((L_allStrips[L_allADCs.index(key)], value) for (key, value) in Dic.items())    #matlab drops columns with names starting with integers (e.g. '80')! -> apply lookuptable here & change column names (starting with one letter)
        Dic['files'] = [file + '_' + key  + '.adc' for file in L_files]
        sio.savemat(fileNameMat, Dic, oned_as='column')


if plotQperStrip:
    filesToPlotCharge = glob.glob(hldOutFolder + '/*.adc')
    if filesToPlotCharge:
        if not os.path.exists(plotFolder): os.makedirs(plotFolder)
    for File in filesToPlotCharge:
        FileName = File.split('/')[-1].split('.')[0]
        df_baseLine = pd.read_pickle(bLineFolder + '/' + FileName + '.bLine')
        df_charge   = pd.read_pickle(chargeFolder + '/' + FileName + '.charge')
        plotIt(plotFrom, plotTo, File, df_baseLine, df_charge, plotFolder)
    print(f"elapsed time (plotQperStrip): {time.time() - t:.3f} s")


if saveAnalysis:
    hld_extension = 'hld'
    if not os.path.exists(savesFolder):
        os.makedirs(savesFolder)
    files = sorted(glob.glob(hldInFolder + '/*.' + hld_extension))
    if files:
        if files[0] == files[-1]:    #one file only in folder files
            folderName = files[0].split('/')[-1].split('.')[0]
        else:
            folderName = files[0].split('/')[-1].split('.')[0] + '-' + files[-1].split('/')[-1].split('.')[0]
        now      = datetime.datetime.now()
        timeNow  = now.strftime("%Y-%m-%d_%Hh%Mm%Ss")
        folderNameForSaves = savesFolder + '/' + f"{folderName}_{timeNow}"    #e.g. .../dabc23037195726-dabc23037195803_2023-02-09_10h53m23s
        os.makedirs(folderNameForSaves)
        folderNameToSaveHLDs = folderNameForSaves + '/hlds'
        os.makedirs(folderNameToSaveHLDs)
    else:
        print(f"No files found in {hldInFolder}.\nThe folder for saves can't be defined. Nothing will be saved.")
        sys.exit()
    Done = 0
    if os.path.isdir(hldOutFolder):
        if compress_hldOutFolder == 1:
            shutil.make_archive(hldOutFolder, 'xztar', hldOutFolder)    #shutil.make_archive('name of the file to create', format, 'directory where we start archiving from')
            shutil.move(hldOutFolder + '.tar.xz', folderNameForSaves)    #formats: xztar (tar.xz), zip...
            shutil.rmtree(hldOutFolder)
            print(f'{hldOutFolder} folder compressed')
        else:
            shutil.move(hldOutFolder, folderNameForSaves)
        Done +=1
    else:
        if unpack:
            print(f'folder not found: {hldOutFolder}')
    if os.path.isdir(chargeFolder):
        shutil.move(chargeFolder, folderNameForSaves)
        Done +=1
    else:
        if convertQandbLine:
            print(f'folder not found: {chargeFolder}')
    if os.path.isdir(bLineFolder):
        shutil.move(bLineFolder, folderNameForSaves)
        Done +=1
    else:
        if convertQandbLine:
            print(f'folder not found: {bLineFolder}')
    if os.path.isdir(timeFolder):
        shutil.move(timeFolder, folderNameForSaves)
        Done +=1
    else:
        if convertTime:
            print(f'folder not found: {timeFolder}')
    if os.path.isdir(plotFolder):
        if os.listdir(plotFolder):    #not empty folder
            shutil.move(plotFolder, folderNameForSaves)
            Done +=1
        else:    #remove empty folder
            print(f'no plots in folder: {plotFolder}, it will be removed')
            shutil.rmtree(plotFolder)
    else:
        if plotQperStrip:
            print(f'folder not found: {plotFolder}')
    if  Done == 0:    #at least hld files were found and sent to folderNameForSaves
        print(f'nothing found to save')
        shutil.rmtree(folderNameForSaves)
    else:    #at least one folder saved; hld files can be moved too
        for file in files:
            shutil.move(file, folderNameToSaveHLDs)    #(source, destination)
        if compress_hldOutFolder == 1:
            shutil.make_archive(folderNameToSaveHLDs, 'xztar', folderNameToSaveHLDs)
            shutil.rmtree(folderNameToSaveHLDs)
            print(f'{folderNameToSaveHLDs} folder compressed')
        print(f"saves done to {folderNameForSaves}")

print(f"Total elapsed time: {time.time() - t:.3f} s")

