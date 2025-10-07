#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
#############
@JPCS_02/2023
#############
"""
###############################################
############## CHANGES HERE ONLY ##############
###############################################
samplesForBaseLine = 10    #base line = mean of the first X ADC samples
samplesTotalNumber = 40
################
################
#LOOKUPTABLE
#NARROW-STRIP PLANES TOGETHER WITH LARGE-STRIP PLANE (06/2023):
#I (strip lado gás) ...                                                                                                       XXIV
ADCsBot = ['23','22','21','20','03','02','01','00','63','62','61','60','73','72','71','70','b3','b2','b1','b0','83','82','81','80']
ADCsTop = ['a3','a2','a1','a0','93','92','91','90','53','52','51','50','43','42','41','40','33','32','31','30','13','12','11','10']

ADCsBot_polarityPulse=-1    #-1 se for pulso negativo (necessário para o trapezoidalFilter)
ADCsTop_polarityPulse=-1

###############################################
###############################################
###############################################

import pandas as pd
import numpy  as np
import os, sys
from collections import OrderedDict


def trapezoidalFilter(L_ADCvalues, polarity):    #Trapezoidal Filter (without pole-zero correction); moving average (df.rolling(3).mean()) too slow
    L=3; G=12    #'best values': G=12, L=3
    L_trapezoidalFilter = []
    for i in range(0,samplesTotalNumber -2*L -G +1):    #samplesTotalNumber -2*L -G +1 -> number of values of the trapezoid
        L_trapezoidalFilter.append(sum(L_ADCvalues[i+L+G:i+2*L+G]) - sum(L_ADCvalues[i:i+L]))
    if polarity == 1:
        return max(list(np.array(L_trapezoidalFilter) // L))
    else:
        return - min(list(np.array(L_trapezoidalFilter) // L))


def QandBlinePerStrip(inputPath):
    if os.path.isfile(inputPath):    #true -> file
        with open(inputPath, 'r+') as f_IN:
            #lineNumber   = 1    -> NOT USED
            dicFromFile  = OrderedDict()
            for line in f_IN:
                L_line = line.split('    ')
                event  = L_line[0]
                dic    = L_line[1]    #d = {'00': [4101,...], '01': [4104,...],...}
                dicFromFile[event] = eval(dic)
                #lineNumber+=1
    else:
        print(f"Check the inputPath. '{inputPath}' does not exist")
        sys.exit()
    df = pd.DataFrame.from_dict(dicFromFile,orient='index')
    #print(df.head(2))
    df = df.drop(['CHs', 'Samples'], axis=1)
    df_baseLine = pd.DataFrame()
    df_charge   = pd.DataFrame()
    for column in df:
        df_baseLine[column] = df[column].apply(lambda x: np.mean(x[0:samplesForBaseLine]))         #base line = mean first X ADC samples
        if column in ADCsBot:
            df_charge[column] = df[column].apply(trapezoidalFilter, polarity=ADCsBot_polarityPulse)    #using trapezoidalFilter
        else:
            df_charge[column] = df[column].apply(trapezoidalFilter, polarity=ADCsTop_polarityPulse)    #using trapezoidalFilter
    df_baseLine.reset_index(inplace=True)    #convert index to column 'EventPerFile'
    df_baseLine = df_baseLine.rename(columns = {'index':'EventPerFile'})
    df_baseLine['EventPerFile'] = df_baseLine['EventPerFile'].astype('int')
    df_charge.reset_index(inplace=True)
    df_charge = df_charge.rename(columns = {'index':'EventPerFile'})
    df_charge['EventPerFile'] = df_charge['EventPerFile'].astype('int')
    return df_baseLine, df_charge    #df_baseLine -> for plot.py


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("\nUsage: ./computeQandBline.py 'input path_dabc*.adc'\n")
        sys.exit(0)
    DF_baseLine, DF_charge = QandBlinePerStrip(sys.argv[1])
    print('baseLine:\n', DF_baseLine)
    print('charge:\n', DF_charge)

