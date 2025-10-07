#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
#############
@JPCS_01/2023
#############
"""
import os, sys
import pandas as pd
import numpy as np
import matplotlib.pylab as plt
from matplotlib.ticker import MaxNLocator, IndexLocator
from computeQandBline import QandBlinePerStrip
from collections import OrderedDict

###############################################
############## CHANGES HERE ONLY ##############
###############################################
plotsToShow   = 2     #1 -> plot with auto Ylim, 2 -> plot with fixed Ylim, 3 -> plot both
savePlots     = 2     #1/2/3; 1 -> show plots and save them in the folder './plots'; 2 -> save only; 3 -> show only
extension     = 'png' # 'jpg', 'png'..
sizePic       = 13    #14
#######
downsampling  = 32
#yMIN = 0; yMAX = downsampling*1024*1.04    #set ylim of fig1 (y shared); +4% above the max
yMIN = -downsampling*512*1.04; yMAX = downsampling*512*1.04    #set ylim of fig1 (y shared); +4% above the max; the base line is subtracted in each plot
#######
sort = 'perStrip'    #'perStrip', 'perADC' or 'perDB'
nROWsCOLs = (4,6) if sort == 'perStrip' else (3,4)    #(4,6): 24chs above and below the RPC -> 4 rows and 6 cols; or 12 ADCs ->(3,4): 3 rows and 4 cols
################
################
############
#LOOKUPTABLE
#I (strip lado gás) ...                                                                                                                 XXIV
#1ST SETUP (caixa pequena com os dois planos de strips finas na mesma dir, um por cima e outro por baixo de uma RPC) -> tem de ser usado com computeQandBline_narrowStripsOnly.py
#ADCsBot = ['80','81','82','83','b0','b1','b2','b3','70','71','72','73','60','61','62','63','00','01','02','03','20','21','22','23']
#TEST FOR SWITCHED CABLES ONLY:
#ADCsBot = ['10','11','12','13','30','31','32','33','40','41','42','43','50','51','52','53','90','91','92','93','a0','a1','a2','a3']
#NARROW-STRIP PLANES TOGETHER WITH LARGE-STRIP PLANE (06/2023):
ADCsBot = ['23','22','21','20','03','02','01','00','63','62','61','60','73','72','71','70','b3','b2','b1','b0','83','82','81','80']

#1ST SETUP (caixa pequena com os dois planos de strips finas na mesma dir, um por cima e outro por baixo de uma RPC) -> tem de ser usado com computeQandBline_narrowStripsOnly.py
#ADCsTop = ['a3','a2','a1','a0','93','92','91','90','53','52','51','50','43','42','41','40','33','32','31','30','13','12','11','10']
#TEST FOR SWITCHED CABLES ONLY:
#ADCsTop = ['23','22','21','20','03','02','01','00','63','62','61','60','73','72','71','70','b3','b2','b1','b0','83','82','81','80']
#NARROW-STRIP PLANES TOGETHER WITH LARGE-STRIP PLANE (06/2023):
ADCsTop = ['a3','a2','a1','a0','93','92','91','90','53','52','51','50','43','42','41','40','33','32','31','30','13','12','11','10']
############



#IF WRONG CONNECTION BETWEEN qFEEoutput AND Addon_connetor: (USED UNTIL dabc23033193054_a004.adc)
#ADCsBot = ['90','91','92','93','a0','a1','a2','a3','40','41','42','43','50','51','52','53','10','11','12','13','30','31','32','33']
#ADCsTop = ['b3','b2','b1','b0','83','82','81','80','63','62','61','60','73','72','71','70','23','22','21','20','03','02','01','00']
plotsToDo = list(zip(ADCsBot,ADCsTop))    #list it otherwise it can't be used twice (zip=generator); [('90', 'b3'), ('91', 'b2'), ..., ('33', '00')] -> 1st item = 1st plot
################
################
#From              -> 1st script argument; create figures from this event
#To                -> 2nd script argument; create figures until this event
#InputPath_ADCfile -> 3rd script argument; input path of a dabc*_a004.adc
#df_baseLine       -> 4th script argument; dataframe with corresponding base line values (obtained from dabc*_a004.bLine)
#df_charge         -> 5th script argument; dataframe with corresponding charge values (obtained from dabc*_a004.charge)
#plotFolder        -> 6th script argument; output path for the figures
###############################################
###############################################
###############################################
#color code: 1st plot -> blue; 2nd -> orange; 3rd -> green; 4th -> red


def plotIt(From, To, InputPath_ADCfile, df_baseLine, df_charge, plotsFolder):
    printEvents = range(int(From),int(To)+1)
    if os.path.isfile(InputPath_ADCfile):    #true -> file
        with open(InputPath_ADCfile, 'r+') as f_IN:
            lineNumber  = 1
            eventsFound = 0
            dicToPlot   = OrderedDict()
            for line in f_IN:
                if lineNumber in printEvents:
                    event = line.split('    ')[0]
                    d     = line.split('    ')[1]    #d = {'00': [4101,...], '01': [4104,...],...}
                    dicToPlot[int(event)] = eval(d)    #convert to int -> needed below: data = df['01'].loc[df['EventPerFile'] == key_event]
                    eventsFound = 1
                else:
                    if eventsFound:
                        break
                lineNumber+=1
    else:
        print(f"Check the inputPath. '{InputPath_ADCfile}' does not exist")
        sys.exit()
    #if plotsToShow == 0:
    #    print('plotsToShow set to 0')
    #else:
    expectedSamples = None
    doItOnce = 1    #savin file's stuff
    for key_event, val_dic in dicToPlot.items():
        samples = dicToPlot[key_event]['Samples'];
        if expectedSamples:
            if expectedSamples != samples:    #since the number of samples is not provided by the user, it does a simple cross-check with the value of samples seen in the previous event
                print(f'Event: {key_event} -> number of samples ({samples}) different than the seen in the previous event ({expectedSamples})')
                print('this event will not be plotted (ADCs in the same event might have different number of samples...)')
                continue    #will not work in case only this event is being plotted! leave like this for now... raised error: ValueError: x and y must have same first dimension, but have shapes (37,) and (38,)
        else:
            expectedSamples = samples
            print(f'number of samples seen in the 1st event (id: {key_event}): {expectedSamples}')
        #chs = dicToPlot[key_event]['CHs']    #dicToPlot[key_event]['CHs'] -> number of chs, currently not used
        x=range(1,samples +1)
        fileName = InputPath_ADCfile.split('/')[-1].split('.')[0]    #beeded for title and in case of saving images
        if plotsToShow == 2 or plotsToShow == 3:
            fig1, ax1 = plt.subplots(nrows=nROWsCOLs[0], ncols=nROWsCOLs[1], sharex=True, sharey=True, figsize=(sizePic, sizePic/1.8)) #sizePic/1.7; default figsize=(~6.4, ~4.8); 6.4/4.8=~1.333
            fig1.suptitle(f"event id:  {key_event}  ({fileName})") #, fontsize=20)
        if plotsToShow == 1 or plotsToShow == 3:
            fig2, ax2 = plt.subplots(nrows=nROWsCOLs[0], ncols=nROWsCOLs[1], sharex=True, figsize=(sizePic, sizePic/1.8))
            fig2.suptitle(f"event id:  {key_event}  ({fileName})")
        plotPerSubPlot=1; n=1; row=0; col=0
        if sort == 'perADC':
            for key,val in val_dic.items():
                Bline = np.mean(val[0:10])
                if plotsToShow == 2 or plotsToShow == 3:
                    ax1[row,col].plot(x, val - Bline)
                if plotsToShow == 1 or plotsToShow == 3:
                    ax2[row,col].plot(x, val - Bline)
                if plotPerSubPlot % 4 == 0:
                    col+=1
                if col == 4:
                    row+=1; col=0
                if row == 3:    #break because the last 2 keys of val_dic ('CHs' and 'Samples') are not to plot
                    break
                plotPerSubPlot+=1
        elif sort == 'perDB':
            Key = ['2','0','6','7','b','8','a','9','5','4','3','1']    #2&0=DB1, 6&7=DB2, b&8=DB3, a&9=DB4, 5&4=DB5, 3&1=DB6
            for key in Key:
                for ch in [0,1,2,3]:
                    Bline = np.mean(val_dic[key + str(ch)][0:10])
                    if plotsToShow == 2 or plotsToShow == 3:
                        ax1[row,col].plot(x, val_dic[key + str(ch)] - Bline)
                    if plotsToShow == 1 or plotsToShow == 3:
                        ax2[row,col].plot(x, val_dic[key + str(ch)]- Bline)
                    if plotPerSubPlot % 4 == 0:
                        col+=1
                    if col == 4:
                        row+=1; col=0
                    plotPerSubPlot+=1
        elif sort == 'perStrip':
            maxCharge_Bottom = -1
            maxCharge_Top    = -1
            for plotToDo in plotsToDo:
                dataCharge = df_charge[plotToDo[0]].loc[df_charge['EventPerFile'] == key_event]; charge_Bottom = dataCharge.values    #charge of the event (strips bottom)
                dataBline  = df_baseLine[plotToDo[0]].loc[df_baseLine['EventPerFile'] == key_event]; baseLine_Bottom  = dataBline.values    #base line of the event
                if maxCharge_Bottom < charge_Bottom:    #keep max values for facecolor (background color of the plots)
                    maxCharge_Bottom = charge_Bottom
                    maxCharge_Bottom_plotRow = row
                    maxCharge_Bottom_plotCol = col
                dataCharge = df_charge[plotToDo[1]].loc[df_charge['EventPerFile'] == key_event]; charge_Top = dataCharge.values    #strips top
                dataBline  = df_baseLine[plotToDo[1]].loc[df_baseLine['EventPerFile'] == key_event]; baseLine_Top  = dataBline.values
                if maxCharge_Top < charge_Top:
                    maxCharge_Top = charge_Top
                    maxCharge_Top_plotRow = row
                    maxCharge_Top_plotCol = col
                if plotsToShow == 2 or plotsToShow == 3:
                    ax1[row,col].plot(x, val_dic[plotToDo[0]] - baseLine_Bottom, label='%d' % charge_Bottom)    #, marker='o', ms='3')
                    ax1[row,col].plot(x, val_dic[plotToDo[1]] - baseLine_Top, label='%d' % charge_Top)
                    ax1[row,col].legend(loc='upper left', frameon=False, fontsize=8, handlelength=1)
                if plotsToShow == 1 or plotsToShow == 3:
                    ax2[row,col].plot(x, val_dic[plotToDo[0]] - baseLine_Bottom, label='%d' % charge_Bottom)
                    ax2[row,col].plot(x, val_dic[plotToDo[1]] - baseLine_Top, label='%d' % charge_Top)
                    ax2[row,col].legend(loc='upper left', frameon=False, fontsize=8, handlelength=1)
                col+=1
                if col == 6:
                    row+=1; col=0
            if plotsToShow == 2 or plotsToShow == 3:
                if maxCharge_Bottom_plotRow == maxCharge_Top_plotRow and maxCharge_Bottom_plotCol == maxCharge_Top_plotCol:
                    ax1[maxCharge_Bottom_plotRow,maxCharge_Bottom_plotCol].set_facecolor('#dbf1d2')
                else:
                    ax1[maxCharge_Bottom_plotRow,maxCharge_Bottom_plotCol].set_facecolor('#eafff5')    #https://www.color-hex.com/color/eafff5
                    ax1[maxCharge_Top_plotRow,maxCharge_Top_plotCol].set_facecolor('#f4eacf') #red -> ('#f5eaff')
            if plotsToShow == 1 or plotsToShow == 3:
                if maxCharge_Bottom_plotRow == maxCharge_Top_plotRow and maxCharge_Bottom_plotCol == maxCharge_Top_plotCol:
                    ax2[maxCharge_Bottom_plotRow,maxCharge_Bottom_plotCol].set_facecolor('#dbf1d2')
                else:
                    ax2[maxCharge_Bottom_plotRow,maxCharge_Bottom_plotCol].set_facecolor('#eafff5')    #https://www.color-hex.com/color/eafff5
                    ax2[maxCharge_Top_plotRow,maxCharge_Top_plotCol].set_facecolor('#f4eacf') #red -> ('#f5eaff')

        if plotsToShow == 2 or plotsToShow == 3:
            #set ylim and xlim of fig1 (x and y shared)
            ax1[0,0].set_ylim([yMIN, yMAX])
            ax1[0,0].xaxis.set_major_locator(IndexLocator(base=5, offset=0))
            ax1[0,0].set_xlim([1, samples])
        if plotsToShow == 1 or plotsToShow == 3:
            #set ylim of fig2 (y not shared)
            for i, ax in enumerate(fig2.axes):    #https://stackoverflow.com/questions/20288842/matplotlib-iterate-subplot-axis-array-through-single-list
                ax.yaxis.set_major_locator(MaxNLocator(integer=True))
                #ax.set_ylabel(str(i))
            #set xlim of fig2 (x shared)
            ax2[0,0].xaxis.set_major_locator(IndexLocator(base=5, offset=0))
            ax2[0,0].set_xlim([1, samples])

        #x and y labels
        if plotsToShow == 2 or plotsToShow == 3:
            fig1.supxlabel('# samples')
            fig1.supylabel('ADC bins * Downsampling')
        if plotsToShow == 1 or plotsToShow == 3:
            fig2.supxlabel('# samples')
            fig2.supylabel('ADC bins * Downsampling')

        #set label of individual subplot
        if sort == 'perADC':    #2&0=DB1, 6&7=DB2, b&8=DB3, a&9=DB4, 5&4=DB5, 3&1=DB6
            if plotsToShow == 2 or plotsToShow == 3:
                ax1[0,0].set_xlabel("DB_1 (ADC_0)"); ax1[0,1].set_xlabel("DB_6 (ADC_1)"); ax1[0,2].set_xlabel("DB_1 (ADC_2)"); ax1[0,3].set_xlabel("DB_6 (ADC_3)")
                ax1[1,0].set_xlabel("DB_5 (ADC_4)"); ax1[1,1].set_xlabel("DB_5 (ADC_5)"); ax1[1,2].set_xlabel("DB_2 (ADC_6)"); ax1[1,3].set_xlabel("DB_2 (ADC_7)")
                ax1[2,0].set_xlabel("DB_3 (ADC_8)"); ax1[2,1].set_xlabel("DB_4 (ADC_9)"); ax1[2,2].set_xlabel("DB_4 (ADC_a)"); ax1[2,3].set_xlabel("DB_3 (ADC_b)")
            if plotsToShow == 1 or plotsToShow == 3:
                ax2[0,0].set_xlabel("DB_6 (ADC_0)"); ax2[0,1].set_xlabel("DB_1 (ADC_1)"); ax2[0,2].set_xlabel("DB_6 (ADC_2)"); ax2[0,3].set_xlabel("DB_1 (ADC_3)")
                ax2[1,0].set_xlabel("DB_2 (ADC_4)"); ax2[1,1].set_xlabel("DB_2 (ADC_5)"); ax2[1,2].set_xlabel("DB_5 (ADC_6)"); ax2[1,3].set_xlabel("DB_5 (ADC_7)")
                ax2[2,0].set_xlabel("DB_4 (ADC_8)"); ax2[2,1].set_xlabel("DB_3 (ADC_9)"); ax2[2,2].set_xlabel("DB_3 (ADC_a)"); ax2[2,3].set_xlabel("DB_4 (ADC_b)")
        elif sort == 'perDB':    #2&0=DB1, 6&7=DB2, b&8=DB3, a&9=DB4, 5&4=DB5, 3&1=DB6
            if plotsToShow == 2 or plotsToShow == 3:
                ax1[0,0].set_xlabel("DB_1 (ADC_2)"); ax1[0,1].set_xlabel("DB_1 (ADC_0)"); ax1[0,2].set_xlabel("DB_2 (ADC_6)"); ax1[0,3].set_xlabel("DB_2 (ADC_7)")
                ax1[1,0].set_xlabel("DB_3 (ADC_b)"); ax1[1,1].set_xlabel("DB_3 (ADC_8)"); ax1[1,2].set_xlabel("DB_4 (ADC_a)"); ax1[1,3].set_xlabel("DB_4 (ADC_9)")
                ax1[2,0].set_xlabel("DB_5 (ADC_5)"); ax1[2,1].set_xlabel("DB_5 (ADC_4)"); ax1[2,2].set_xlabel("DB_6 (ADC_3)"); ax1[2,3].set_xlabel("DB_6 (ADC_1)")
            if plotsToShow == 1 or plotsToShow == 3:
                ax2[0,0].set_xlabel("DB_1 (ADC_2)"); ax2[0,1].set_xlabel("DB_1 (ADC_0)"); ax2[0,2].set_xlabel("DB_2 (ADC_6)"); ax2[0,3].set_xlabel("DB_2 (ADC_7)")
                ax2[1,0].set_xlabel("DB_3 (ADC_b)"); ax2[1,1].set_xlabel("DB_3 (ADC_8)"); ax2[1,2].set_xlabel("DB_4 (ADC_a)"); ax2[1,3].set_xlabel("DB_4 (ADC_9)")
                ax2[2,0].set_xlabel("DB_5 (ADC_5)"); ax2[2,1].set_xlabel("DB_5 (ADC_4)"); ax2[2,2].set_xlabel("DB_6 (ADC_3)"); ax2[2,3].set_xlabel("DB_6 (ADC_1)")
        elif sort == 'perStrip':    #based on plotsToDo
            if plotsToShow == 2 or plotsToShow == 3:
                ax1[0,0].set_xlabel("I"); ax1[0,1].set_xlabel("II"); ax1[0,2].set_xlabel("III"); ax1[0,3].set_xlabel("IV"); ax1[0,4].set_xlabel("V"); ax1[0,5].set_xlabel("VI")
                ax1[1,0].set_xlabel("VII"); ax1[1,1].set_xlabel("VIII"); ax1[1,2].set_xlabel("IX"); ax1[1,3].set_xlabel("X"); ax1[1,4].set_xlabel("XI"); ax1[1,5].set_xlabel("XII")
                ax1[2,0].set_xlabel("XIII"); ax1[2,1].set_xlabel("XIV"); ax1[2,2].set_xlabel("XV"); ax1[2,3].set_xlabel("XVI"); ax1[2,4].set_xlabel("XVII"); ax1[2,5].set_xlabel("XVIII")
                ax1[3,0].set_xlabel("XIX"); ax1[3,1].set_xlabel("XX"); ax1[3,2].set_xlabel("XXI"); ax1[3,3].set_xlabel("XXII"); ax1[3,4].set_xlabel("XXIII"); ax1[3,5].set_xlabel("XXIV")
            if plotsToShow == 1 or plotsToShow == 3:
                ax2[0,0].set_xlabel("I"); ax2[0,1].set_xlabel("II"); ax2[0,2].set_xlabel("III"); ax2[0,3].set_xlabel("IV"); ax2[0,4].set_xlabel("V"); ax2[0,5].set_xlabel("VI")
                ax2[1,0].set_xlabel("VII"); ax2[1,1].set_xlabel("VIII"); ax2[1,2].set_xlabel("IX"); ax2[1,3].set_xlabel("X"); ax2[1,4].set_xlabel("XI"); ax2[1,5].set_xlabel("XII")
                ax2[2,0].set_xlabel("XIII"); ax2[2,1].set_xlabel("XIV"); ax2[2,2].set_xlabel("XV"); ax2[2,3].set_xlabel("XVI"); ax2[2,4].set_xlabel("XVII"); ax2[2,5].set_xlabel("XVIII")
                ax2[3,0].set_xlabel("XIX"); ax2[3,1].set_xlabel("XX"); ax2[3,2].set_xlabel("XXI"); ax2[3,3].set_xlabel("XXII"); ax2[3,4].set_xlabel("XXIII"); ax2[3,5].set_xlabel("XXIV")
        #plt.show(block=False)
        if savePlots == 1 or savePlots == 2:
            if doItOnce:
                if not os.path.exists(plotsFolder):
                    os.makedirs(plotsFolder)
                print(f"plots saved in folder: {plotsFolder}")
                doItOnce = 0
            if plotsToShow == 2 or plotsToShow == 3:
                fig1.savefig(plotsFolder + '/' + fileName + '_Yfixed_' + sort + '_id-' + str(key_event) + '.' + extension)
                fig1.clear()
                plt.close(fig1)
            if plotsToShow == 1 or plotsToShow == 3:
                fig2.savefig(plotsFolder + '/' + fileName + '_Yauto_'  + sort + '_id-' + str(key_event) + '.' + extension)
                fig2.clear()
                plt.close(fig2)
    if savePlots == 1 or savePlots == 3:
        plt.pause(0.001) # Pause for interval seconds.
        input("hit[enter] to end.")
        plt.close('all') # all open plots are correctly closed after each run


if __name__ == "__main__":
    if len(sys.argv) != 7:
        print("\nUsage: ./plot.py 'from' 'to' 'input path_dabc*.adc' 'InputPath_dFrame_bLine' 'InputPath_dFrame_charge' 'outputPath_saveFigs'\n")
        sys.exit(0)
    df_baseLine = pd.read_pickle(sys.argv[4])
    df_charge   = pd.read_pickle(sys.argv[5])
    plotIt(int(sys.argv[1]),int(sys.argv[2]),sys.argv[3],df_baseLine,df_charge,sys.argv[6])



"""
###
create a second (new) plot, then later plot on the old one?
https://stackoverflow.com/questions/6916978/how-do-i-tell-matplotlib-to-create-a-second-new-plot-then-later-plot-on-the-o

###
Tick locators -> https://matplotlib.org/3.1.1/gallery/ticks_and_spines/tick-locators.html
from matplotlib.ticker import MaxNLocator, IndexLocator
ax.xaxis.set_major_locator(MaxNLocator(integer=True))
ax.xaxis.set_major_locator(IndexLocator(base=2, offset=1))

###
legends -> https://stackoverflow.com/questions/4700614/how-to-put-the-legend-outside-the-plot
shift the legend slightly outside the axes boundaries: ax.legend(bbox_to_anchor=(1.1, 1.05))
make the legend more horizontal and/or put it at the top of the figure: ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.05), ncol=3, fancybox=True, shadow=True)
legends (handlelength) -> https://stackoverflow.com/questions/20048352/how-to-adjust-the-size-of-matplotlib-legend-box

# Shrink current axis by 20%: box = ax.get_position(); ax.set_position([box.x0, box.y0, box.width * 0.8, box.height])
# Put a legend to the right of the current axis: ax.legend(loc='center left', bbox_to_anchor=(1, 0.5))

# Shrink current axis's height by 10% on the bottom: box = ax.get_position(); ax.set_position([box.x0, box.y0 + box.height * 0.1, box.width, box.height * 0.9])
# Put a legend below current axis: ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.05), fancybox=True, shadow=True, ncol=5)

###
diferent way to plot:
fig1 = plt.figure(1); ax1 = plt.subplot(341)    #(lines, cols, plotNumberOfThisCol)
fig2 = plt.figure(2); ax2 = plt.subplot(341)
d = {'00': [4181, 4190, 4192, 4196, 4193, 4189, 4180, 4157, 4124, 4042, 3877, 3832, 3896, 3979, 4045, 4087, 4124, 4151, 4170, 4178], '01': [4112, 4117, 4121, 4123, 4120, 4120, 4120, 41>
x=range(1,21)
plotPerSubPlot = 1; n=1; line=1; col=1
for key,val in d.items():
    plt.figure(1)
    ax1 = plt.subplot(3,4,n)
    plt.plot(x, val)
    ax1.xaxis.set_major_locator(IndexLocator(base=2, offset=1))
    ax1.set_ylim([0, 5000])
    plt.xlim(1, 20)
    plt.figure(2)
    ax2 = plt.subplot(3,4,n)
    plt.plot(x, val)
    if plotPerSubPlot == 4:
        n+=1
        plotPerSubPlot=0
    plotPerSubPlot+=1
    if n == 13:
        break
"""

