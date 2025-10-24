#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
#############
@JPCS_12/2022
#############
"""
import pandas as pd
import os, sys

pd.set_option('display.max_columns', None)    # Force Pandas to display all columns
pd.set_option('display.width', 185)           # Set the display width to a very large number (arbitrarily high)


def readDFrame(inputPath):
    if os.path.isfile(inputPath):    #true -> file
        df = pd.read_pickle(inputPath)
        return df

def custom_sort_key(col):
    # Check if the column name starts with 'l' or 't' and has a number
    if col[0] in ['l', 't'] and len(col) > 1 and col[1:].isdigit():
        letter = col[0]           # Extract the first character
        number = int(col[1:])     # Extract the numeric part and convert to int
        return (letter, number)    # Return a tuple (letter, number)
    else:
        # If the format is not as expected, return a default value for sorting
        return (col[0], float('inf'))  # Place these at the end of the sort

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("\nUsage: ./readDataFrame.py 'input path/dabc*.time or dabc*.charge or dabc*.bLine'\n")
        sys.exit(0)
    file = sys.argv[1]
    extension=file.rsplit('.')[1]    #extension can be charge, bLine or time; if extension = time -> better to sort the DF
    print('Provided file:\n', file)
    DF = readDFrame(file)
    if extension == 'time':
        sorted_cols = sorted(DF.columns, key=custom_sort_key)
        DF = DF[sorted_cols]
    print('###########\nFirst lines of the dataframe:\n', DF.head(2))
    #print(DF.loc[[698]])
    #print(DF.loc[DF['EventPerFile'] == 699])
    #print(DF.loc[DF['EventPerFile'].isin([698,699])].to_string())
    #print(DF.loc[(DF['EventPerFile'] >= 690) & (DF['EventPerFile'] <= 700)].to_string())
    print('###########\nstatistics:\n' ,DF.describe())


